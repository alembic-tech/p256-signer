pragma solidity ^0.8.0;

import {FCL_WebAuthn} from "FreshCryptoLib/FCL_Webauthn.sol";

/// @title P256Signer
/// @notice A contract used to verify ECDSA signatures over secp256r1 through
///         EIP-1271 of Webauthn payloads.
/// @dev This contract is the implementation. It is meant to be used through
///      proxy clone.
contract P256Signer {
    /// @notice The EIP-1271 magic value
    bytes4 internal constant EIP1271_MAGICVALUE = 0x1626ba7e;

    /// @notice The old EIP-1271 magic value
    bytes4 internal constant OLD_EIP1271_MAGICVALUE = 0x20c13b0b;

    /// @notice Whether the contract has been initialized
    bool public initialized;

    /// @notice The x coordinate of the secp256r1 public key
    uint256 public x;

    /// @notice The y coordinate of the secp256r1 public key
    uint256 public y;

    /// @notice Error message when the signature is invalid
    error InvalidSignature();

    /// @notice Error message when the hash is invalid
    error InvalidHash();

    /// @notice Error message when the contract is already initialized
    error AlreadyInitialized();

    constructor() {
        initialized = true;
    }

    /// @notice Verifies that the signer is the owner of the secp256r1 public key.
    /// @param _hash The hash of the data signed
    /// @param _signature The signature
    /// @return The EIP-1271 magic value
    function isValidSignature(bytes32 _hash, bytes calldata _signature) public view returns (bytes4) {
        _validate(abi.encode(_hash), _signature);
        return EIP1271_MAGICVALUE;
    }

    /// @notice Verifies that the signer is the owner of the secp256r1 public key.
    /// @dev This is the old version of the function of EIP-1271 using bytes
    ///      memory instead of bytes32
    /// @param _hash The hash of the data signed
    /// @param _signature The signature
    /// @return The EIP-1271 magic value
    function isValidSignature(bytes memory _hash, bytes calldata _signature) public view returns (bytes4) {
        _validate(_hash, _signature);
        return OLD_EIP1271_MAGICVALUE;
    }

    struct SignatureLayout {
        bytes authenticatorData;
        bytes clientData;
        uint256 challengeOffset;
        uint256[2] rs;
    }

    /// @notice Validates the signature
    /// @param data The data signed
    /// @param _signature The signature
    function _validate(bytes memory data, bytes calldata _signature) private view {
        bytes32 _hash = keccak256(data);
        SignatureLayout calldata signaturePointer;
        // This code should precalculate the offsets of variables as defined in the layout
        // Calldata variables are represented as offsets, and, I think, length for dynamic types
        // If the calldata is malformed (e.g., shorter than expected), this will revert with an out of bounds error
        assembly {
            signaturePointer := _signature.offset
        }

        bool valid = FCL_WebAuthn.checkSignature(
            signaturePointer.authenticatorData,
            0x01,
            signaturePointer.clientData,
            _hash,
            signaturePointer.challengeOffset,
            signaturePointer.rs,
            x,
            y
        );

        if (!valid) revert InvalidSignature();
    }

    /// @dev This function is only callable once and needs to be called immediately
    ///      after deployment by the factory in the same transaction.
    /// @param x_ The x coordinate of the public key
    /// @param y_ The y coordinate of the public key
    function initialize(uint256 x_, uint256 y_) external {
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        x = x_;
        y = y_;
    }
}
