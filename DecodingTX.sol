// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "solidity-rlp/contracts/RLPReader.sol";
import "fhevm/lib/TFHE.sol";

/**
    * @dev This contract decodes raw, serialised Ethereum transactions. 
    *
    * This contract contains one primary function (decodeTX) in addition to three helper functions 
    * to aid in decoding raw transaction into the nonce, gasPrice, gasLimit, to, value and data. 
    *
    */
contract TXDecoder {
    
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    struct Data {
        bytes methodID;
        euint64 amountIn;
        euint64 amountOutMin;
        euint64 addressOffset;
        eaddress dataTo;
        euint64 deadline;
        euint64 addressLength;
        eaddress token1;
        eaddress token2;
    }
    struct DecodedTX {
        euint64 nonce;
        euint64 gasPrice;
        euint64 gasLimit;
        eaddress to;
        euint64 value;
        Data data;
    }

    /**
        * 
        * @dev Takes the RLP encoded transactions and returns an encrypted 
        * struct of the transaction parameters.
        * 
        * @param {encodedTX} the RLP encoded transaction.
        * @return FHE Encrypted, RLP decoded transaction.
        *
        */
    function decodeTX(bytes memory encodedTx) public pure returns(DecodedTX memory){ 
        
        euint64 nonce = TFHE.asEuint64(encodedTx.toRlpItem().toList()[0].toUint()); 
        euint64 gasPrice = TFHE.asEuint64(encodedTx.toRlpItem().toList()[1].toUint()); 
        euint64 gasLimit = TFHE.asEuint64(encodedTx.toRlpItem().toList()[2].toUint()); 
        eaddress to = TFHE.asEaddress(encodedTx.toRlpItem().toList()[3].toAddress()); 
        euint64 value = TFHE.asEuint64(encodedTx.toRlpItem().toList()[4].toUint()); 
        Data memory decodedData;
        
        // DATA
        bytes memory data = encodedTx.toRlpItem().toList()[5].toBytes();
        bytes memory methodID = extractBytes(data, 0, 4);

        if(uint8(methodID[0]) == 0x18){ 
            //tokens for eth
            decodedData = decodeTokensForEth(data);
        }else if(uint8(methodID[0]) == 0x7f){
            //eth for tokens
            decodedData = decodeEthForTokens(data);
        } else{
            revert("Invalid Function");
        }

        //Probably not needed !! 
        // euint64 v = TFHE.asEuint64(encodedTx.toRlpItem().toList()[6].toUint()); 
        // euint64 r = TFHE.asEuint64(encodedTx.toRlpItem().toList()[7].toBytes());
        // euint64 s = TFHE.asEuint64(encodedTx.toRlpItem().toList()[8].toBytes());

        return DecodedTX(nonce, gasPrice, gasLimit, to, value, decodedData);
    }

    /**
        * 
        * @dev Copies slices of an array into an new variable.
        *
        * @param {input} The initial array to be sliced. 
        * @param {start} The starting index of the slice.
        * @param {len} The length of the slice. 
        * @return 
        *
        */
    function extractBytes(bytes memory input, uint256 start, uint256 len) internal pure returns (bytes memory) {
        require(start + len <= input.length, "Overflow!"); // Check bounds
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = input[start + i];
        }
        return result;
    }

    /**
        * 
        * @dev Decodes and encrypts the abi encoded input data field of the transaction 
        * for the Tokens for Eth uniswapV2 functions.
        *
        * @param {data} the data field of the transaction.
        * @return The data struct containing the parameters included in the data fields. 
        *
        */
    function decodeTokensForEth(bytes memory data) internal pure returns(Data memory){
        euint64 amountIn = TFHE.asEuint64(abi.decode(extractBytes(data, 4, 32), (uint256))); 
        euint64 amountOutMin = TFHE.asEuint64(abi.decode(extractBytes(data, 36, 32), (uint256))); 
        euint64 addressOffset = TFHE.asEuint64(abi.decode(extractBytes(data, 68, 32), (uint256)));
        eaddress dataTo = TFHE.asEaddress(abi.decode(extractBytes(data, 100, 32), (address))); 
        euint64 deadline = TFHE.asEuint64(abi.decode(extractBytes(data, 132, 32), (uint256))); 
        euint64 addressLength = TFHE.asEuint64(abi.decode(extractBytes(data, 164, 32), (uint256)));
        eaddress token1 = TFHE.asEaddress(abi.decode(extractBytes(data, 196, 32), (address))); 
        eaddress token2 = TFHE.asEaddress(abi.decode(extractBytes(data, 228, 32), (address))); 
        return Data(extractBytes(data, 0, 4),amountIn, amountOutMin, addressOffset, dataTo, deadline, addressLength, token1, token2);
    }

    /**
        * 
        * @dev Decodes and encrypts the abi encoded input data field of the transaction 
        * for the Eth for Tokens uniswapV2 functions.
        *
        * @param {data} the data field of the transaction.
        * @return The data struct containing the parameters included in the data fields. 
        *
        */
    function decodeEthForTokens(bytes memory data) internal pure returns(Data memory){
        // self made
        euint64 amountIn = TFHE.asEuint64(0);  
        euint64 amountOutMin = TFHE.asEuint64(abi.decode(extractBytes(data, 4, 32), (uint256))); 
        euint64 addressOffset = TFHE.asEuint64(abi.decode(extractBytes(data, 36, 32), (uint256)));
        eaddress dataTo = TFHE.asEaddress(abi.decode(extractBytes(data, 68, 32), (address))); 
        euint64 deadline = TFHE.asEuint64(abi.decode(extractBytes(data, 100, 32), (uint256)));
        euint64 addressLength = TFHE.asEuint64(abi.decode(extractBytes(data, 132, 32), (uint256)));
        eaddress token1 = TFHE.asEaddress(abi.decode(extractBytes(data, 164, 32), (address))); 
        eaddress token2 = TFHE.asEaddress(abi.decode(extractBytes(data, 196, 32), (address))); 
        return Data(extractBytes(data, 0, 4), amountIn, amountOutMin, addressOffset, dataTo, deadline, addressLength, token1, token2);
    }
}
