// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./lib/TFHE.sol";
import "solidity-rlp/contracts/RLPReader.sol";

contract MultipleTx {

    uint256 maxRatio = 0 ;
    uint256 maxIndex = 100;
    uint256 maxEth = 0;
    uint256 maxUSDT = 0;
    uint256 newEthReserves;
    uint256 newUSDTReserves;
    euint64 amountIn;
    bytes methodID;
    euint64 targetAmountIn;
    bytes targetMethodID;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;


    /*
        * 
        * @dev Combines multiple user transactions and returns the most profitable combination. 
        * @param {userTransaction1} First user transaction.
        * @param {userTransaction2} Second user transaction.
        * @param {userTransaction3} Third user transaction.
        * @param {userTransaction4} Fourth user transaction.
        * @param {EthInPool} Ethereum reserves in the pool.
        * @param {USDTInPool} USDT reserves in the pool.
        * @return {userTransaction} The most profitable target transaction. 
        * @return {newEth} Ethereum reserves after applying all non-target transactions. 
        * @return {newUSDT} USDT reserves after applying all non-target transactions. 
        *
    */
    function combineMultipleTransaction(bytes memory userTransaction1, bytes memory userTransaction2, bytes memory userTransaction3, bytes memory userTransaction4, uint256 EthInPool, uint256 USDTInPool) public returns(bytes memory, uint256, uint256){ 

        bytes[] memory txs = new bytes[](4);
        txs[0] = userTransaction1;
        txs[1] = userTransaction2;
        txs[2] = userTransaction3;
        txs[3] = userTransaction4;

        for(uint i = 0; i < 4 ; i++){
            // For all potential target transactions 
            (targetAmountIn, targetMethodID) = getAmountIn(txs[i]);

            // reset reserves
            newEthReserves  = (EthInPool);
            newUSDTReserves = (USDTInPool);
            
            // reset amounts traded in
            uint256 ethSum = 0;
            uint256 usdtSum = 0;

            // reset ratio
            uint256 ratio = 0;

            for(uint j = 0; j < 4; j++){ 
                // get sum of all amounts traded in
                if(j != i){
                    (amountIn, methodID) = getAmountIn(txs[j]);
                    if(methodID[0] == 0x18){
                        // tokens for Eth
                        usdtSum = (usdtSum + TFHE.decrypt(amountIn));
                    }else{
                        //ETH for tokens
                        ethSum = (ethSum + (TFHE.decrypt(amountIn) / 1000000000000));
                    }
                }
            }
            // calculate reserves 
            (newEthReserves, newUSDTReserves) = updateEthTrade(newEthReserves, newUSDTReserves, ethSum);  
            (newEthReserves, newUSDTReserves) = updateUsdtTrade(newEthReserves, newUSDTReserves, usdtSum); 


            // calculate ratios 
            if(targetMethodID[0] == 0x18){
                // Tokens For Eth
                ratio = (uint256(TFHE.decrypt(targetAmountIn)) * 1000000) / newUSDTReserves;

            }else{
                // Eth For Tokens
                ratio = (TFHE.decrypt(targetAmountIn) / 1000000) / newEthReserves;

            }

            if(ratio > maxRatio){
                maxRatio = ratio;
                maxIndex = i;
                maxEth = newEthReserves;
                maxUSDT = newUSDTReserves;
            }
        }
        return (txs[maxIndex], maxEth, maxUSDT); 
    }

    /**
        * 
        * @dev Updates the reserves based on Eth traded in
        * 
        * @param {eth} The original Eth reserves.
        * @param {usdt} The original USDT reserves.
        * @param {amount} Amount of Eth Traded in.
        * @return The updated reserves.
        *
    */
    function updateEthTrade(uint256 eth, uint256 usdt, uint256 amount) internal pure returns(uint256, uint256){
        uint256 k = eth * usdt;
        uint256 updatedEth = eth + amount;
        uint256 updatedUSDT = k / updatedEth;
        return (updatedEth, updatedUSDT);
    }

    /**
        * 
        * @dev Updates the reserves based on USDT traded in
        * 
        * @param {eth} The original Eth reserves.
        * @param {usdt} The original USDT reserves.
        * @param {amount} Amount of USDT Traded in.
        * @return The updated reserves.
        *
    */
    function updateUsdtTrade(uint256 eth, uint256 usdt, uint256 amount) internal pure returns(uint256, uint256){
        uint256 k = eth * usdt;
        uint256 updatedUSDT = usdt + amount;
        uint256 updatedEth = k / updatedUSDT;
        return (updatedEth, updatedUSDT);
    }

    /**
        * 
        * @dev Takes the RLP encoded transactions and returns 
        * the amount traded in 
        * 
        * @param {encodedTX} The RLP encoded transaction.
        * @return The amount traded as well as the methodID
        *
    */
    function getAmountIn(bytes memory encodedTx) internal pure returns(euint64, bytes memory){ 

        euint64 xamountIn;
        bytes memory data = encodedTx.toRlpItem().toList()[5].toBytes();
        bytes memory xmethodID = extractBytes(data, 0, 4);

        if(uint8(xmethodID[0]) == 0x18){ 
            // Tokens For Eth
            xamountIn = TFHE.asEuint64(abi.decode(extractBytes(data, 4, 32), (uint64)));
        }else if(uint8(xmethodID[0]) == 0x7f){
            // Eth For Tokens
            xamountIn = TFHE.asEuint64(encodedTx.toRlpItem().toList()[4].toUint()); 
        } else{
            revert("Invalid Function");
        }
        
        return (xamountIn, xmethodID);
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
}
