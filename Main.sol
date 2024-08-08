// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./RLPCoder.sol";
import "./Backrun.sol";

contract Main{


    RLPCoder public RLP;
    Backrun public backrun;
    address UNISWAPV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    bool valid = true; 

    struct ProfitConstants{
        euint64 EthInPool; // from searcher
        euint64 USDTInPool; // from searcher
        uint64 EthPrecision; //number of decimals for WETH (fixed)
        euint64 maxBuyPrice; // max buy price from searcher
        euint64 minSellPrice; // min sell price from searcher
        euint64 costOfArbitrage; // fixed 2 USDT
        euint64 encryptedFour;
        euint64 encryptedZero;
    }

    /**
        * 
        * @dev The main function of the backrunning program. This function takes both the user's transaction as well as the searcher's strategy to return
        * a backrunning transaction which exploits the price shift caused by the user's transaction. 
        * 
        * @param {userTransaction} The RLP encoded user transaction which is being backrun. 
        * @param {EthInPool} The amount of Ethereum in the pool.
        * @param {USDTInPool} The amount of USDT in the pool.
        * @param {maxBuyPrice} The searcher's maximum price to purchase the desired token.
        * @param {minSellPrice} The searcher's minimum price to sell the desired token.
        * @param {searcherNonce} The searcher's nonce.
        * @param {searcherAddress} The address of the searcher's wallet.
        * @return {backrunningTransaction} The encoded, backrunning transaction.
        *
        */
    function BackrunTX(bytes memory userTransaction, uint256 EthInPool, uint256 USDTInPool, uint32 maxBuyPrice, uint32 minSellPrice, uint8 searcherNonce, address searcherAddress) public returns(bytes memory){
        RLP = new RLPCoder();
        backrun = new Backrun();
        RLPCoder.DecodedTX memory decodedTransaction = RLP.decodeTX(userTransaction);
        ProfitConstants memory constants = ProfitConstants(TFHE.asEuint64(EthInPool), TFHE.asEuint64(USDTInPool), 1000000000000000000, TFHE.asEuint64(maxBuyPrice), TFHE.asEuint64(minSellPrice), TFHE.asEuint64(2000000), TFHE.asEuint64(4), TFHE.asEuint64(0));
        euint64 X;
        euint64 Y;
        bytes memory searcherMethodID;
        euint64 amountOut;
        RLPCoder.Data memory finalData;
        RLPCoder.DecodedTX memory finalTransaction ;
        euint64 eamountIn;
        euint64 profit;
        
        //User comparisons 
        if(decodedTransaction.to == UNISWAPV2_ROUTER && decodedTransaction.data.deadline >= 1669870000 && decodedTransaction.data.addressLength == 2){
            valid = true;
            // update token quantites
            (X, Y, searcherMethodID) = backrun.updateTokenQuantities(decodedTransaction, constants);
            // calculating amount in 
            eamountIn = backrun.amountCalculation(constants, X, Y);
            // calculating profits 
            (profit, amountOut) = backrun.calculateProfits(decodedTransaction, X, Y, eamountIn, constants);
            // Searcher Comparisons 
            if(TFHE.decrypt(eamountIn) > 0 && TFHE.decrypt(profit) > 0){
                profit = TFHE.sub(profit, constants.costOfArbitrage);
                valid =  true;
            }else{
                valid =  false;
            }
        }else{
            valid = false;
        }
        
        if(valid == true){
            if (searcherMethodID[0] == 0x18){
                // tokens for Eth 
                finalData = RLPCoder.Data(searcherMethodID, eamountIn, amountOut, 160 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, constants.encryptedZero, finalData);
            }else{
                // Eth for tokens
                finalData = RLPCoder.Data(searcherMethodID, constants.encryptedZero, amountOut, 128 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, eamountIn, finalData);
            }
        }else{
            // Return 0 transaction
            finalData = RLPCoder.Data('0', constants.encryptedZero, constants.encryptedZero, 0 ,0x0000000000000000000000000000000000000000, 0, 0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000);
            finalTransaction = RLPCoder.DecodedTX(0, 0, 0, 0x0000000000000000000000000000000000000000, constants.encryptedZero, finalData);
        }
        return (RLP.encodeTX(finalTransaction));
    } 
}