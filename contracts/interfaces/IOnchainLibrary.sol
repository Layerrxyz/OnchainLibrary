// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IContractScript} from "./IContractScript.sol";

/**
 * @title OnchainLibrary
 * @author 0xth0mas (Layerr)
 * @notice OnchainLibrary is an open repository of assets that
 *         anyone may use and contribute to.
 */
interface IOnchainLibrary is IContractScript {

    /// @dev asset metadata
    struct Asset {
        uint56 assetId;
        address uploadedBy;
        uint32 dataChunkCount;
        bool finalized;
        bool hashValidated;
        bytes32 expectedSHA256Hash;
        string name;
    }

    /// @dev array of assets matching a specific hash for searching
    struct CatalogEntry {
        uint256[] assets;
    }

    /// @dev Emitted when an asset is added to the library
    event AssetAdded(uint256 indexed assetId, bytes32 indexed expectedSHA256Hash, uint32 dataChunkCount, string name);
    /// @dev Emitted when the uploader updates the assets metadata
    event AssetUpdated(uint256 indexed assetId, bytes32 indexed expectedSHA256Hash, uint32 dataChunkCount, string name);
    /// @dev Emitted when the uploader finalizes an asset
    event AssetFinalized(uint256 indexed assetId);
    /// @dev Emitted when a data chunk is added to an asset
    event DataChunkUploaded(uint256 indexed assetId, uint256 indexed chunkId, address indexed chunkDataPointer);
    /// @dev Emitted when an asset's hash actual onchain hash is validated against its expected hash
    event AssetHashValidated(uint256 indexed assetId, bytes32 indexed actualSHA256Hash);


    /// @dev thrown when attempting to modify an asset that the sender did not initiate
    error NotUploader();
    /// @dev thrown when attempting to update a finalized asset
    error AssetIsFinalized();
    /// @dev thrown when attempting to use an asset that is not finalized
    error AssetNotFinalized();
    /// @dev thrown when attempting to upload a data chunk outside the specified range
    error ExceedsChunkCount();
    /// @dev thrown when attempting to store a data chunk larger than the max data chunk size
    error ExceedsMaxChunkSize();
    /// @dev thrown when expected hash does not match the actual asset hash
    error HashMismatch();

    /**
     * @notice Begin the process of uploading an asset to the library.
     * @param name Name of the asset
     * @param expectedSHA256Hash Expected SHA256 hash when asset is finalized
     * @param dataChunkCount Number of data chunks that will be uploaded
     * @return newAssetId The ID of the asset that was created
     */
    function addAsset(string calldata name, bytes32 expectedSHA256Hash, uint32 dataChunkCount) external returns(uint256 newAssetId);

    /**
     * @notice Update asset information
     * @dev This should be restricted to the uploader of the asset 
     *      and not allow updates after asset is marked finalized.
     * @param assetId ID of the asset being updated
     * @param name Name of the asset
     * @param expectedSHA256Hash Expected SHA256 hash when asset is finalized
     * @param dataChunkCount Number of data chunks that will be uploaded
     */
    function updateAsset(uint256 assetId, string calldata name, bytes32 expectedSHA256Hash, uint32 dataChunkCount) external;

    /**
     * @notice Finalize an asset to prevent future changes.
     * @dev This should be restricted to the uploader of the asset.
     * @param assetId ID of the asset being finalized
     */
    function finalizeAsset(uint256 assetId) external;

    /**
     * @notice Uploads a chunk of data to the asset at a specified index
     * @param assetId ID of the asset
     * @param chunkId Index position for the chunk of data within the asset
     * @param chunkData Data to be stored for the asset at chunkId index
     */
    function uploadChunk(uint256 assetId, uint256 chunkId, bytes calldata chunkData) external;


    /**
     * @notice Uploads a chunk of data to the asset at a specified index
     * @param assetId ID of the asset
     * @param chunkId Index position for the chunk of data within the asset
     * @param chunkDataPointer Address of the chunkData stored in SSTORE2 format
     */
    function addChunkByAddress(uint256 assetId, uint256 chunkId, address chunkDataPointer) external;

    /**
     * @notice Searches the catalog for all assets matching the expectedHash
     * @param expectedHash The expected hash value to search for
     * @return assetsFound All matches in the catalog for the expectedHash
     */
    function searchCatalogByExpectedHash(bytes32 expectedHash) external view returns(Asset[] memory assetsFound);

    /**
     * @notice Searches the catalog for all assets matching the validatedHash.
     *         Validated hashes have been confirmed onchain by calculating the
     *         hash of the asset's data and comparing to the expected hash for
     *         the asset. Only finalized assets can have a validated hash.
     * @param validatedHash The validated hash value to search for
     * @return assetsFound All matches in the catalog for the validatedHash
     */
    function searchCatalogByValidatedHash(bytes32 validatedHash) external view returns(Asset[] memory);

    /**
     * @notice Searches the catalog for all assets matching the given name.
     * @param name The asset name to search for
     * @return assetsFound All matches in the catalog for the name
     */
    function searchCatalogByName(string calldata name) external view returns(Asset[] memory);

    /**
     * @notice Searches the catalog for all assets uploaded by an address.
     * @param uploadedBy The uploader to search for
     * @return assetsFound All matches in the catalog for the uploader
     */
    function searchCatalogByUploader(address uploadedBy) external view returns(Asset[] memory);

    /**
     * @notice Gets asset data for the given assetIds
     * @param assetIds IDs of the assets to return data for
     * @return assetArr the asset data for the given assetIds
     */
    function getAssetsById(uint256[] memory assetIds) external view returns(Asset[] memory assetArr);

    /**
     * @notice Returns the address that a data chunk will be stored at and if it already exists
     * @dev Data chunks are stored using SSTORE2 with a CREATE2 address based on the init code to prevent
     *      duplication of data.
     * @param dataChunk data chunk that will be or is stored
     * @return pointer storage address for the data chunk
     * @return isUploaded flag if the data chunk is already uploaded
     */
    function getDataChunkAddress(bytes calldata dataChunk) external view returns(address pointer, bool isUploaded);

    /**
     * @notice Validates an asset's expected hash matches its actual hash
     *         and store the result onchain.
     * @param assetId ID of the asset being validated
     * @return hashesMatch true if actual hash and expected hash are the same
     */
    function validateActualAndExpectedHashOnchain(uint256 assetId) external returns(bool hashesMatch);

    /**
     * @notice Checks an asset's expected hash compared to its actual hash.
     *         Does not update onchain data. Only checks finalized assets.
     * @param assetId ID of the asset being checked
     * @return hashesMatch true if actual hash and expected hash are the same
     */
    function validateActualAndExpectedHash(uint256 assetId) external view returns(bool hashesMatch);

    /**
     * @notice Checks an asset's expected hash compared to its actual hash.
     *         Does not update onchain data. Checks finalized and unfinalized assets.
     * @param assetId ID of the asset being checked
     * @return hashesMatch true if actual hash and expected hash are the same
     */
    function validateUnfinalizedActualAndExpectedHash(uint256 assetId) external view returns(bool hashesMatch);

    /**
     * @notice Reads the bytes data stored for the asset.
     *         Only reads finalized assets.
     * @param assetId ID of the asset
     * @return assetBytes bytes data for the asset
     */
    function getAssetBytes(uint256 assetId) external view returns(bytes memory assetBytes);

    /**
     * @notice Reads the bytes data stored for the asset.
     *         Reads finalized and unfinalized assets.
     * @param assetId ID of the asset
     * @return assetBytes bytes data for the asset
     */
    function getUnfinalizedAssetBytes(uint256 assetId) external view returns(bytes memory assetBytes);

    /**
     * @notice Reads the bytes data stored for the asset and converts to Base64.
     *         Only reads finalized assets.
     * @param assetId ID of the asset
     * @return assetBase64 base64 data for the asset
     */
    function getAssetBase64(uint256 assetId) external view returns(string memory assetBase64);

    /**
     * @notice Reads the bytes data stored for the asset and converts to Base64.
     *         Reads finalized and unfinalized assets.
     * @param assetId ID of the asset
     * @return assetBase64 base64 data for the asset
     */
    function getUnfinalizedAssetBase64(uint256 assetId) external view returns(string memory assetBase64);

    /**
     * @notice Reads the bytes data stored for the asset and converts to a string.
     *         Only reads finalized assets.
     * @param assetId ID of the asset
     * @return assetString string data for the asset
     */
    function getAssetString(uint256 assetId) external view returns(string memory assetString);

    /**
     * @notice Reads the bytes data stored for the asset and converts to a string.
     *         Reads finalized and unfinalized assets.
     * @param assetId ID of the asset
     * @return assetString string data for the asset
     */
    function getUnfinalizedAssetString(uint256 assetId) external view returns(string memory assetString);

    /**
     * @notice Reads the bytes data stored for the asset and calculates the SHA256 hash.
     *         Only reads finalized assets.
     * @param assetId ID of the asset
     * @return assetHash hash of the asset data
     */
    function getAssetActualSHA256Hash(uint256 assetId) external view returns(bytes32 assetHash);

    /**
     * @notice Reads the bytes data stored for the asset and calculates the SHA256 hash.
     *         Reads finalized and unfinalized assets.
     * @param assetId ID of the asset
     * @return assetHash hash of the asset data
     */
    function getUnfinalizedAssetActualSHA256Hash(uint256 assetId) external view returns(bytes32 assetHash);
}