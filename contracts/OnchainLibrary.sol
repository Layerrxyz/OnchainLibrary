// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOnchainLibrary} from "./interfaces/IOnchainLibrary.sol";
import {SSTORE2} from "./lib/SSTORE2/SSTORE2.sol";
import {Base64} from "./lib/solady/utils/Base64.sol";

/**
 * @title OnchainLibrary
 * @author 0xth0mas (Layerr)
 * @notice OnchainLibrary is an unowned, immutable repository
 *         for onchain assets that anyone may contribute to
 *         and use.
 *         Data chunks are stored in deterministic addresses 
 *         to prevent duplicate data from being stored on chain.
 *         Pointers to the existing data can be queried and used in
 *         new asset files.
 */
contract OnchainLibrary is IOnchainLibrary {

    uint256 public constant MAX_CHUNK_SIZE = 24575;

    mapping(uint256 => Asset) public assets;
    mapping(bytes32 => CatalogEntry) private catalog;
    mapping(uint256 => mapping(uint256 => address)) public dataChunks;

    uint256 public nextAssetId = 1;

    /**
     * Upload Asset
     */

    /**
     * @inheritdoc IOnchainLibrary
     */
    function addAsset(string calldata name, bytes32 expectedSHA256Hash, uint32 dataChunkCount) external returns(uint256 newAssetId) {
        newAssetId = nextAssetId;
        unchecked { ++nextAssetId; }

        Asset storage asset = assets[newAssetId];
        asset.assetId = uint56(newAssetId);
        asset.name = name;
        asset.uploadedBy = msg.sender;
        asset.dataChunkCount = dataChunkCount;
        asset.expectedSHA256Hash = expectedSHA256Hash;

        CatalogEntry storage catalogEntry = catalog[keccak256(abi.encodePacked(msg.sender))];
        catalogEntry.assets.push(newAssetId);
        emit AssetAdded(newAssetId, expectedSHA256Hash, dataChunkCount, name);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function updateAsset(uint256 assetId, string calldata name, bytes32 expectedSHA256Hash, uint32 dataChunkCount) external {
        Asset storage asset = assets[assetId];
        if(msg.sender != asset.uploadedBy) revert NotUploader();
        if(asset.finalized) revert AssetIsFinalized();

        asset.name = name;
        asset.dataChunkCount = dataChunkCount;
        asset.expectedSHA256Hash = expectedSHA256Hash;
        emit AssetUpdated(assetId, expectedSHA256Hash, dataChunkCount, name);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function finalizeAsset(uint256 assetId) external {
        Asset storage asset = assets[assetId];
        if(msg.sender != asset.uploadedBy) revert NotUploader();
        if(asset.finalized) revert AssetIsFinalized();
        CatalogEntry storage catalogEntry;

        asset.finalized = true;
        catalogEntry = catalog[keccak256(abi.encodePacked(asset.expectedSHA256Hash))];
        catalogEntry.assets.push(assetId);
        catalogEntry = catalog[keccak256(bytes(asset.name))];
        catalogEntry.assets.push(assetId);

        emit AssetFinalized(assetId);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function uploadChunk(uint256 assetId, uint256 chunkId, bytes calldata chunkData) external {
        if(chunkData.length > MAX_CHUNK_SIZE) revert ExceedsMaxChunkSize();

        Asset storage asset = assets[assetId];
        if(msg.sender != asset.uploadedBy) revert NotUploader();
        if(asset.finalized) revert AssetIsFinalized();
        if(chunkId >= asset.dataChunkCount) revert ExceedsChunkCount();

        address chunkDataPointer = SSTORE2.write(chunkData);
        dataChunks[assetId][chunkId] = chunkDataPointer;
        emit DataChunkUploaded(assetId, chunkId, chunkDataPointer);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function addChunkByAddress(uint256 assetId, uint256 chunkId, address chunkDataPointer) external {
        Asset storage asset = assets[assetId];
        if(msg.sender != asset.uploadedBy) revert NotUploader();
        if(asset.finalized) revert AssetIsFinalized();
        if(chunkId >= asset.dataChunkCount) revert ExceedsChunkCount();

        dataChunks[assetId][chunkId] = chunkDataPointer;
        emit DataChunkUploaded(assetId, chunkId, chunkDataPointer);
    }

    /**
     * Catalog Search
     */

    /**
     * @inheritdoc IOnchainLibrary
     */
    function searchCatalogByExpectedHash(bytes32 expectedHash) external view returns(Asset[] memory foundAssets) {
        uint256[] memory assetIds = catalog[keccak256(abi.encodePacked(expectedHash))].assets;
        foundAssets = _getAssetsById(assetIds);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function searchCatalogByValidatedHash(bytes32 validatedHash) external view returns(Asset[] memory foundAssets) {
        uint256[] memory assetIds = catalog[keccak256(abi.encodePacked(validatedHash,true))].assets;
        foundAssets = _getAssetsById(assetIds);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function searchCatalogByName(string calldata name) external view returns(Asset[] memory foundAssets) {
        uint256[] memory assetIds = catalog[keccak256(bytes(name))].assets;
        foundAssets = _getAssetsById(assetIds);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function searchCatalogByUploader(address uploadedBy) external view returns(Asset[] memory foundAssets) {
        uint256[] memory assetIds = catalog[keccak256(abi.encodePacked(uploadedBy))].assets;
        foundAssets = _getAssetsById(assetIds);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getAssetsById(uint256[] memory assetIds) external view returns(Asset[] memory assetArr) {
        assetArr = _getAssetsById(assetIds);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getDataChunkAddress(bytes calldata dataChunk) external view returns(address pointer, bool isUploaded) {
        (pointer, isUploaded) = SSTORE2.search(dataChunk);
    }

    /**
     * Hash Validation
     */

    /**
     * @inheritdoc IOnchainLibrary
     */
    function validateActualAndExpectedHashOnchain(uint256 assetId) external returns(bool) {
        Asset storage asset = assets[assetId];
        bytes32 actualSHA256Hash = _getAssetActualSHA256Hash(assetId, false);
        asset.hashValidated = assets[assetId].expectedSHA256Hash == actualSHA256Hash;
        if(!asset.hashValidated) revert HashMismatch();
        CatalogEntry storage catalogEntry = catalog[keccak256(abi.encodePacked(asset.expectedSHA256Hash, true))];
        catalogEntry.assets.push(assetId);
        emit AssetHashValidated(assetId, actualSHA256Hash);

        return asset.hashValidated;
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function validateActualAndExpectedHash(uint256 assetId) external view returns(bool hashesMatch) {
        hashesMatch = assets[assetId].expectedSHA256Hash == _getAssetActualSHA256Hash(assetId, false);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function validateUnfinalizedActualAndExpectedHash(uint256 assetId) external view returns(bool hashesMatch) {
        hashesMatch = assets[assetId].expectedSHA256Hash == _getAssetActualSHA256Hash(assetId, true);
    }

    /**
     * Asset Retrieval
     * Read as bytes, base64, string or hash
     */

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getAssetBytes(uint256 assetId) external view returns(bytes memory assetBytes) {
        assetBytes = _getAssetBytes(assetId, false);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getUnfinalizedAssetBytes(uint256 assetId) external view returns(bytes memory assetBytes) {
        assetBytes = _getAssetBytes(assetId, true);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getAssetBase64(uint256 assetId) external view returns(string memory assetBase64) {
        assetBase64 = Base64.encode(_getAssetBytes(assetId, false));
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getUnfinalizedAssetBase64(uint256 assetId) external view returns(string memory assetBase64) {
        assetBase64 = Base64.encode(_getAssetBytes(assetId, true));
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getAssetString(uint256 assetId) external view returns(string memory assetString) {
        assetString = string(_getAssetBytes(assetId, false));
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getUnfinalizedAssetString(uint256 assetId) external view returns(string memory assetString) {
        assetString = string(_getAssetBytes(assetId, true));
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getAssetActualSHA256Hash(uint256 assetId) external view returns(bytes32 assetHash) {
        assetHash = _getAssetActualSHA256Hash(assetId, false);
    }

    /**
     * @inheritdoc IOnchainLibrary
     */
    function getUnfinalizedAssetActualSHA256Hash(uint256 assetId) external view returns(bytes32 assetHash) {
        assetHash = _getAssetActualSHA256Hash(assetId, true);
    }

    /**
     * @notice Backwards compatible function for contracts using ScriptyBuilder
     * @param data bytes array that will be converted to assetId
     * @return script bytes array of the asset's stored data
     */
    function getScript(string calldata, bytes memory data) external view returns (bytes memory script) {
        uint256 assetId;
        for(uint256 dataIndex;dataIndex < data.length && dataIndex < 32;) {
            assetId |= (uint256(uint8(data[dataIndex])) << (248 - 8 * dataIndex));

            unchecked { ++dataIndex; }
        }
        script = _getAssetBytes(assetId, false);
    }

    /**
     * @notice Returns the asset's stored data in bytes, reverts if asset is not finalized and allowUnfinalized is false
     */
    function _getAssetBytes(uint256 assetId, bool allowUnfinalized) internal view returns(bytes memory assetBytes) {
        Asset storage asset = assets[assetId];

        if(!allowUnfinalized && !asset.finalized) revert AssetNotFinalized();

        address[] memory dataChunkAddresses = new address[](asset.dataChunkCount);

        for(uint256 chunkIndex;chunkIndex < asset.dataChunkCount;) {
            dataChunkAddresses[chunkIndex] = dataChunks[assetId][chunkIndex];

            unchecked { ++chunkIndex; }
        }

        assetBytes = SSTORE2.readMultiple(dataChunkAddresses);
    }

    /**
     * @notice Returns the SHA256 hash of the asset's stored data in bytes
     *         Reverts if asset is not finalized and allowUnfinalized is false
     */
    function _getAssetActualSHA256Hash(uint256 assetId, bool allowUnfinalized) internal view returns(bytes32 assetHash) {
        bytes memory assetBytes = _getAssetBytes(assetId, allowUnfinalized);
        assetHash = sha256(assetBytes);
    } 

    /**
     * @notice Returns an array of Asset objects for a given array of assetIds
     */
    function _getAssetsById(uint256[] memory assetIds) internal view returns(Asset[] memory assetArr) {
        assetArr = new Asset[](assetIds.length);

        for(uint256 assetIndex = 0;assetIndex < assetIds.length;) {
            assetArr[assetIndex] = assets[assetIds[assetIndex]];
            unchecked { ++assetIndex; }
        }
    }
}