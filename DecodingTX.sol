// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecodingTX{

    // Constants for RLP encoding prefixes
    uint8 constant STRING_ASIS_START = 0x00; //0
    uint8 constant STRING_SHORT_START = 0x80; //128
    uint8 constant STRING_LONG_START = 0xb8; //184
    uint8 constant LIST_SHORT_START = 0xc0; //192
    uint8 constant LIST_LONG_START = 0xf8; //248

    struct DecodedTransaction {
        bytes nonce;
        bytes gasPrice;
        bytes gasLimit;
        bytes to;
        bytes value;
        bytes v;
        bytes r;
        bytes s;
    }

    event debug(string message,uint256 x, uint256 y);

    function decodeTX(bytes calldata rawTransaction) public{
        DecodedTransaction memory userTX = decodeRawTransaction(rawTransaction);
        // emit DecodedTransaction()
    }

    function decodeRawTransaction(bytes memory rawTransaction)  internal returns (DecodedTransaction memory){
        bytes[] memory items = decode(rawTransaction);
        require(items.length >= 8, "Transaction length is too short!");
        return DecodedTransaction({
            nonce: items[0],
            gasPrice: items[1],
            gasLimit: items[2],
            to: items[3],
            value: items[4],
            v: items[5],
            r: items[6],
            s: items[7]
        });

    }

    function decode(bytes memory userTX)  internal returns(bytes[] memory){
        uint256 offset;
        uint256 dataLen;

        if(userTX.length == 0){
            return new bytes[](0);
        }
        
        (offset, dataLen) = decodeLength(userTX);
        emit debug("DEBUGGGG!!!!!!!", dataLen, offset);
        

        bytes[] memory items = new bytes[](dataLen);
        for (uint256 i = 0; i < dataLen; i++) {
            uint256 length;
            (items[i], length) = decodeItem(userTX, offset);
            offset += length;
        }
        return items;
    }

    function decodeLength(bytes memory userTX) pure internal returns(uint256, uint256){
        uint256 length = uint256(userTX.length);
        uint8 prefix = uint8(userTX[0]);

        require(length > 0, "Cannot get Length of Null item!");
        require(prefix >= 0xc0, "Not a list");

        if(prefix <= 0xf7 && length > prefix - 0xbf){
            // short list
            return(1,prefix - 0xc0);

        }else if(prefix <= 0xff && length > prefix - 0xf7){
            // long list
            uint256 lenOfListLen = prefix - 0xf7;
            uint256 listLen = toInteger(extractBytes(userTX, 1, lenOfListLen));
            return(1 + lenOfListLen,listLen);

        }else{
            // IF not conforming to RLP standards
            revert("ERROR!!!");
        }
    }

    function decodeItem(bytes memory userTX, uint256 offset) internal returns (bytes memory, uint256){
        uint8 prefix = uint8(userTX[offset]);
        if (prefix <= 0x7f){
            // decode as is (byte)
            return (bytes(abi.encodePacked(userTX[offset])), 1);
        } else if (prefix <= 0xb7) {
            // TODO: ?? 
            // decode short string
            uint256 length = prefix - 0x80;
            
            emit debug("Before error causing!", length, userTX.length);
            // Running around 200 time
            // TODO: causing issues
            return (extractBytes(userTX, offset+1, length), length + 1);

        } else if (prefix <= 0xbf) {
            // TODO: ??
            // decoding long string
            uint256 lengthLength = prefix - 0xb9;
            uint256 length = toInteger(extractBytes(userTX, offset + 1, lengthLength));
            return (_copy(userTX, offset + lengthLength + 1, length), length + lengthLength + 1);
        } else if (prefix <= 0xf7) {
            // decoding short list!
            revert("Decoding lists not supported in this function");
        } else {
            revert("Invalid RLP item prefix");
        }
    }

    function extractBytes(bytes memory input, uint256 start, uint256 len) internal pure returns (bytes memory) {
        bytes memory result = new bytes(1);
        for (uint256 i = 0; i < len; i++) {
            result[i] = input[start + i];
        }
        return result;
    }

    function toInteger(bytes memory b) internal pure returns (uint256) {
        uint256 length = b.length;
        require(length > 0, "Input is null");

        uint256 result = 0;
        for (uint256 i = 0; i < length; i++) {
            result = result * 256 + uint8(b[i]);
        }
        return result;
    }
    function _copy(bytes memory data, uint256 offset, uint256 length) pure internal returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[offset + i];
        }
        return result;
    }

}


