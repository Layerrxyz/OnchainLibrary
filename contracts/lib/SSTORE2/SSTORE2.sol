// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/Bytecode.sol";

/**
  @title A key-value storage with auto-generated keys for storing chunks of data with a lower write & read cost.
  @author Agustin Aguilar <aa@horizon.io>

  Readme: https://github.com/0xsequence/sstore2#readme
*/
library SSTORE2 {
  error WriteError();
  error DataAlreadyExists(address pointer);

  /**
    @notice Stores `_data` and returns `pointer` as key for later retrieval
    @dev The pointer is a contract address with `_data` as code
    @param _data to be written
    @return pointer Pointer to the written `_data`
  */
  function write(bytes memory _data) internal returns (address pointer) {
    // Append 00 to _data so contract can't be called
    // Build init code
    bytes memory initCode = Bytecode.creationCodeFor(
      abi.encodePacked(
        hex'00',
        _data
      )
    );

    pointer = findCreate2Address(initCode);
    if(Bytecode.codeSize(pointer) > 0) revert DataAlreadyExists(pointer);

    // Deploy contract using create
    assembly { pointer := create2(0, add(initCode, 0x20), mload(initCode), 0) }

    // Address MUST be non-zero
    if (pointer == address(0)) revert WriteError();
  }

  /**
    @notice Looks up the create2 address for `_data`
    @param _data to look up
    @return pointer Pointer to where `_data` is or will be stored
  */
  function search(bytes memory _data) internal view returns (address pointer, bool isUploaded) {
    // Append 00 to _data so contract can't be called
    // Build init code
    bytes memory initCode = Bytecode.creationCodeFor(
      abi.encodePacked(
        hex'00',
        _data
      )
    );

    pointer = findCreate2Address(initCode);
    isUploaded = Bytecode.codeSize(pointer) > 0;
  }

  /**
   * @dev Compute the address of the contract that will be created when
   * submitting a given salt or nonce to the contract along with the contract's
   * initialization code. The CREATE2 address is computed in accordance with
   * EIP-1014, and adheres to the formula therein of
   * `keccak256( 0xff ++ address ++ salt ++ keccak256(init_code)))[12:]` when
   * performing the computation. The computed address is then checked for any
   * existing contract code - if so, the null address will be returned instead.
   * From 0age's Keyless CREATE2 factory
   * @param initCode bytes The contract initialization code to be used.
   * that will be passed into the CREATE2 address calculation.
   * @return deploymentAddress Address of the contract that will be created, or the null address
   * if a contract has already been deployed to that address.
   */
  function findCreate2Address(
    bytes memory initCode
  ) internal view returns (address deploymentAddress) {
    // determine the address where the contract will be deployed.
    deploymentAddress = address(
      uint160(                      // downcast to match the address type.
        uint256(                    // convert to uint to truncate upper digits.
          keccak256(                // compute the CREATE2 hash using 4 inputs.
            abi.encodePacked(       // pack all inputs to the hash together.
              hex"ff",              // start with 0xff to distinguish from RLP.
              address(this),        // this contract will be the caller.
              uint256(0),           // pass in the supplied salt value.
              keccak256(            // pass in the hash of initialization code.
                abi.encodePacked(
                  initCode
                )
              )
            )
          )
        )
      )
    );
  }

  /**
    @notice Reads the contents of the `_pointer` code as data, skips the first byte 
    @dev The function is intended for reading pointers generated by `write`
    @param _pointer to be read
    @return data read from `_pointer` contract
  */
  function read(address _pointer) internal view returns (bytes memory) {
    return Bytecode.codeAt(_pointer, 1, type(uint256).max);
  }


  /**
    @notice Reads the contents of the `_pointer` code as data, skips the first byte 
    @dev The function is intended for reading pointers generated by `write`
  */
  function readMultiple(address[] memory _pointers) internal view returns (bytes memory) {
    return Bytecode.codeAtMultiple(_pointers);
  }

  /**
    @notice Reads the contents of the `_pointer` code as data, skips the first byte 
    @dev The function is intended for reading pointers generated by `write`
    @param _pointer to be read
    @param _start number of bytes to skip
    @return data read from `_pointer` contract
  */
  function read(address _pointer, uint256 _start) internal view returns (bytes memory) {
    return Bytecode.codeAt(_pointer, _start + 1, type(uint256).max);
  }

  /**
    @notice Reads the contents of the `_pointer` code as data, skips the first byte 
    @dev The function is intended for reading pointers generated by `write`
    @param _pointer to be read
    @param _start number of bytes to skip
    @param _end index before which to end extraction
    @return data read from `_pointer` contract
  */
  function read(address _pointer, uint256 _start, uint256 _end) internal view returns (bytes memory) {
    return Bytecode.codeAt(_pointer, _start + 1, _end + 1);
  }
}