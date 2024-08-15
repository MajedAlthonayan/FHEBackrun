// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "solidity-rlp/contracts/RLPReader.sol";
import "./lib/TFHE.sol";
import "https://github.com/bakaoh/solidity-rlp-encode/blob/master/contracts/RLPEncode.sol" ;



/**
    * @dev This contract decodes raw, serialised Ethereum transactions. 
    *
    * This contract contains one primary function (decodeTX) in addition to three helper functions 
    * to aid in decoding raw transaction into the nonce, gasPrice, gasLimit, to, value and data. 
    *
    */
contract RLPCoder {
    
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using RLPEncode for uint;
    using RLPEncode for bytes;
    using RLPEncode for address;
    using RLPEncode for bytes[];

    
    struct Data {
        bytes methodID;
        euint64 amountIn;
        euint64 amountOutMin; 
        uint256 addressOffset;
        address dataTo; 
        uint256 deadline;
        uint256 addressLength;
        address token1; 
        address token2;
    }
    struct DecodedTX {
        uint256 nonce; 
        uint256 gasPrice;
        uint256 gasLimit;
        address to;
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
        uint256 nonce = encodedTx.toRlpItem().toList()[0].toUint(); 
        uint256 gasPrice = encodedTx.toRlpItem().toList()[1].toUint(); 
        uint256 gasLimit = encodedTx.toRlpItem().toList()[2].toUint(); 
        address toAddress = (encodedTx.toRlpItem().toList()[3].toAddress()); 
        euint64 value = TFHE.asEuint64(encodedTx.toRlpItem().toList()[4].toUint()); 
        Data memory decodedData;

        // Data
        bytes memory data = encodedTx.toRlpItem().toList()[5].toBytes();
        bytes memory methodID = extractBytes(data, 0, 4);

        if(uint8(methodID[0]) == 0x18){ 
            // Tokens For Eth
            decodedData = decodeTokensForEth(data);
        }else if(uint8(methodID[0]) == 0x7f){
            // Eth For Tokens
            decodedData = decodeEthForTokens(data);
        } else{
            revert("Invalid Function");
        }
        

        return (DecodedTX(nonce, gasPrice, gasLimit, toAddress, value, decodedData));
    }

    /**
        * 
        * @dev Takes a decrypted transaction, and returns the RLP encoded, serialised
        * bytes
        *
        * @param {transaction} The decoded transaction containing the searcher's backrunning transaction.  
        * @return The RLP encoded, serialised transaction. 
        *
    */
    function encodeTX(DecodedTX memory transaction) public view returns(bytes memory){ 
        bytes[] memory dataArray = new bytes[](9);
        bytes[] memory TxArray = new bytes[](6);
        
        // encode Transaction
        TxArray[0] = transaction.nonce.encodeUint();
        TxArray[1] = transaction.gasPrice.encodeUint();
        TxArray[2] = transaction.gasLimit.encodeUint();
        TxArray[3] = transaction.to.encodeAddress();

        dataArray[0] = transaction.data.methodID;
        uint i = 1;

        if(transaction.data.methodID[0] == 0x18){
            // tokens for Eth 
            TxArray[4] = uint(0).encodeUint();
            dataArray[1] = abi.encode(uint(TFHE.decrypt(transaction.data.amountIn)));
            i = 2;
        }else{
            // Eth for tokens 
            TxArray[4] = uint(TFHE.decrypt(transaction.value)).encodeUint();
        }

        dataArray[i] = abi.encode(uint(TFHE.decrypt(transaction.data.amountOutMin)));
        dataArray[i+1] = abi.encode(transaction.data.addressOffset);
        dataArray[i+2] = abi.encode(transaction.data.dataTo);
        dataArray[i+3] = abi.encode(transaction.data.deadline);
        dataArray[i+4] = abi.encode(transaction.data.addressLength);
        dataArray[i+5] = abi.encode(transaction.data.token1);
        dataArray[i+6] = abi.encode(transaction.data.token2);
        
        bytes memory dataConcat = bytes.concat(dataArray[0],dataArray[1],dataArray[2], dataArray[3], dataArray[4], dataArray[5], dataArray[6], dataArray[7], dataArray[8]);
        TxArray[5] = dataConcat.encodeBytes();
        return (TxArray.encodeList());
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
        euint64 amountIn = TFHE.asEuint64(abi.decode(extractBytes(data, 4, 32), (uint64)));
        euint64 amountOutMin = TFHE.asEuint64(abi.decode(extractBytes(data, 36, 32), (uint256))); 
        uint256 addressOffset = abi.decode(extractBytes(data, 68, 32), (uint256));
        address dataTo = abi.decode(extractBytes(data, 100, 32), (address)); 
        uint256 deadline = abi.decode(extractBytes(data, 132, 32), (uint256)); 
        uint256 addressLength = abi.decode(extractBytes(data, 164, 32), (uint256));
        address token1 = abi.decode(extractBytes(data, 196, 32), (address)); 
        address token2 = abi.decode(extractBytes(data, 228, 32), (address)); 
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
        euint64 amountIn = TFHE.asEuint64(uint64(0));
        euint64 amountOutMin = TFHE.asEuint64(abi.decode(extractBytes(data, 4, 32), (uint256))); 
        uint256 addressOffset = abi.decode(extractBytes(data, 36, 32), (uint256));
        address dataTo = abi.decode(extractBytes(data, 68, 32), (address)); 
        uint256 deadline = abi.decode(extractBytes(data, 100, 32), (uint256));
        uint256 addressLength = abi.decode(extractBytes(data, 132, 32), (uint256));
        address token1 = abi.decode(extractBytes(data, 164, 32), (address)); 
        address token2 = abi.decode(extractBytes(data, 196, 32), (address));
        return Data(extractBytes(data, 0, 4), amountIn, amountOutMin, addressOffset, dataTo, deadline, addressLength, token1, token2);
    }
}
