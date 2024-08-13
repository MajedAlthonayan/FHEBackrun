// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./RLPCoder.sol";
import "./Backrun.sol";

contract MultipleTX {
    RLPCoder internal RLP;
    Backrun internal backrun;

    euint64 maxRatio = TFHE.asEuint64(0); 
    euint64 maxIndex = TFHE.asEuint64(100); 
    euint64 newEth;
    euint64 newUSDT;
    euint64 amountIn;
    bytes methodID;
    euint64 targetAmountIn;
    bytes targetMethodID;


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
        RLP = new RLPCoder();
        backrun = new Backrun();

        bytes[] memory txs = new bytes[](4);
        txs[0] = userTransaction1;
        txs[1] = userTransaction2;
        txs[2] = userTransaction3;
        txs[3] = userTransaction4;

        for(uint i = 0; i < 4 ; i++){
            // For all transactions 
            newEth  = TFHE.asEuint64(EthInPool);
            newUSDT = TFHE.asEuint64(USDTInPool);
            euint64 ethSum = TFHE.asEuint64(0);
            euint64 usdtSum = TFHE.asEuint64(0);
            euint64 ratio;
            (targetAmountIn, targetMethodID) = RLP.getAmountIn(txs[i]);

            for(uint j = 0; j < 4; j++){ 
                // get sum of all amounts traded in
                if(j != i){
                    (amountIn, methodID) = RLP.getAmountIn(txs[j]);
                    if(methodID[0] == 0x18){
                        // tokens for Eth
                        usdtSum = TFHE.add(usdtSum, amountIn);
                    }else{
                        //ETH for tokens
                        ethSum = TFHE.add(ethSum, amountIn);
                    }
                }
            }

            // calculate reserves 
            (newEth, newUSDT, methodID) = backrun.updateTokenQuantities(TFHE.asEuint64(0), ethSum, hex"7ff36ab5", newEth, newUSDT);  // 6 Million
            (newEth, newUSDT, methodID) = backrun.updateTokenQuantities(usdtSum, TFHE.asEuint64(0), hex"18cbafe5", newEth, newUSDT); // 6 Million 

            // calculate ratios 
            if(methodID[0] == 0x18){
                // Tokens For Eth
                ratio = TFHE.div(amountIn, TFHE.decrypt(newUSDT));
            }else{
                // Eth For Tokens
                ratio = TFHE.div(TFHE.div(amountIn, 1000000000000), TFHE.decrypt(newEth));

            }

            // if ratio > max Ratio 
            ebool isAbove = TFHE.gt(ratio, maxRatio);
            maxRatio = TFHE.select(isAbove, ratio, maxRatio);
            maxIndex = TFHE.select(isAbove, TFHE.asEuint64(i), maxIndex);
        }
        return (txs[TFHE.decrypt(maxIndex)], TFHE.decrypt(newEth), TFHE.decrypt(newUSDT));
    }
}
