// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./RLPCoder.sol";
import "./Backrun.sol";
import "./MultipleTx.sol";

contract Main{


    RLPCoder internal RLP;
    Backrun internal backrun;
    MultipleTx internal combineTx;
    bool valid; 

    struct ProfitConstants{
        euint64 EthInPool; // From searcher.
        euint64 USDTInPool; // From searcher.
        uint64 EthPrecision; // Number of decimals for WETH (fixed).
        euint64 maxBuyPrice; // Max buy price from searcher.
        euint64 minSellPrice; // Min sell price from searcher.
        euint64 encryptedFour; // Constant for calculation.
        euint64 encryptedZero; // Constant for calculation.
        euint64 amountIn; // The amount the searcher should trade in.
        euint64 amountOut; // The amount received from the searcher's trade. 
        euint64 profit; // The profit from the searcher's trade. 
        euint64 X; // Amount of token1 in the pool.
        euint64 Y; // Amount of token2 in the pool. 
        bytes searcherMethodID; // methodID of the searcher's backrunning transaction
    }
    RLPCoder.DecodedTX decodedTransaction;
    ProfitConstants searcherConstants;
    RLPCoder.Data finalData;
    RLPCoder.DecodedTX finalTransaction;
    bytes userTransaction;
    uint256 updatedEth;
    uint256 updatedUSDT;


    /**
        * 
        * @dev First main function of the searcher protocol. This function combines the transactions and
        * returns the most optimal order.
        * 
        * @param {userTransaction1}
        * @param {userTransaction2}
        * @param {userTransaction3}
        * @param {userTransaction4} 
        * @param {EthInPool} The amount of Ethereum in the pool.
        * @param {USDTInPool} The amount of USDT in the pool.
        * @param {maxBuyPrice} The searcher's maximum price to purchase the desired token.
        * @param {minSellPrice} The searcher's minimum price to sell the desired token.
        * @return {userTransaction}
        * @return {updatedEth} 
        * @return {updatedUSDT}
        *
    */
    function combineTransactions(bytes memory userTransaction1, bytes memory userTransaction2, bytes memory userTransaction3, bytes memory userTransaction4, uint256 EthInPool, uint256 USDTInPool) public returns(bytes memory, uint256, uint256){
        combineTx = new MultipleTx();
        // Find optimal combination of the four transactions
        (userTransaction, updatedEth, updatedUSDT) = combineTx.combineMultipleTransaction(userTransaction1, userTransaction2, userTransaction3, userTransaction4, EthInPool, USDTInPool);

        return (userTransaction, updatedEth, updatedUSDT);
    }

    /**
        * 
        * @dev Second main function of the searcher protocol. This function updates the uniswap pools based on the user's trade.
        * 
        * @param {maxBuyPrice} The searcher's maximum price to purchase the desired token.
        * @param {minSellPrice} The searcher's minimum price to sell the desired token.
        * @return {valid} The boolean which 
        *
    */
    function updatePools(uint32 maxBuyPrice, uint32 minSellPrice) public returns(bool){
        // Update Pools
        RLP = new RLPCoder();
        backrun = new Backrun();

        decodedTransaction = RLP.decodeTX(userTransaction);
        
        searcherConstants = ProfitConstants(TFHE.asEuint64(updatedEth), TFHE.asEuint64(updatedUSDT), 1000000000000, TFHE.asEuint64(maxBuyPrice), TFHE.asEuint64(minSellPrice), TFHE.asEuint64(4), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), "0x00000000"); 
        
        //User transaction comparisons
        if(decodedTransaction.to == 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D && decodedTransaction.data.deadline >= 1669870000 && decodedTransaction.data.addressLength == 2){
            valid = true;
            // update token quantites
            (searcherConstants.X, searcherConstants.Y, searcherConstants.searcherMethodID) = backrun.updateTokenQuantities(decodedTransaction.data.amountIn, decodedTransaction.value, decodedTransaction.data.methodID, searcherConstants.EthInPool, searcherConstants.USDTInPool); 

        }else{
            valid = false;
        }
        return valid;
    }

    /**
        * 
        * @dev Second function of the main protocol which performs the calculation that calculates the amount to trade in. 
        * 
        * @return {valid} The boolean which 
        *
    */
    function amountInCalc() public returns(bool){
        //User transaction comparisons
        if(valid == true){
            // calculating amount in 
            searcherConstants.amountIn = backrun.amountCalculation(searcherConstants, searcherConstants.X, searcherConstants.Y); 

        }else{
            valid = false;
        }
        return valid;
    }

    /**
        * 
        * @dev Third function of the main protocol which calculates the profit based on the previously calculated amount. 
        * 
        * @return {valid} The boolean which 
        *
    */
    function profitCalc() public returns(bool){
        //User transaction comparisons
        if(valid == true){
            // calculating profits 
            (searcherConstants.profit, searcherConstants.amountOut) = backrun.calculateProfits(searcherConstants.X, searcherConstants.Y, searcherConstants.amountIn, searcherConstants); 
            // Searcher transaction comparisons 
            if(TFHE.decrypt(TFHE.or(TFHE.lt(searcherConstants.amountIn, 0) , TFHE.lt(searcherConstants.profit, 2000000)))){
                valid =  false;
            }else{
                searcherConstants.profit = TFHE.sub(searcherConstants.profit, 2000000); 
            }
        }else{
            valid = false;
        }
        return valid;
    }

    /**
        * 
        * @dev Last function of the main protocol which builds the backrunning transaction.
        * 
        * @return {finalTransaction} The backrunning transaction. 
        *
    */
    function buildSearcherTX(uint8 searcherNonce, address searcherAddress) public returns(bytes memory, bytes memory){

        if(valid == true){
            if (searcherConstants.searcherMethodID[0] == 0x18){
                // Tokens For Eth 
                finalData = RLPCoder.Data(searcherConstants.searcherMethodID, searcherConstants.amountIn, searcherConstants.amountOut, 160 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, searcherConstants.encryptedZero, finalData);
            }else{
                // Eth For Tokens
                finalData = RLPCoder.Data(searcherConstants.searcherMethodID, searcherConstants.encryptedZero, searcherConstants.amountOut, 128 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, TFHE.mul(searcherConstants.amountIn, 1000000000000), finalData);
            }
        }else{
            // Return 0 transaction
            finalData = RLPCoder.Data('0', searcherConstants.encryptedZero, searcherConstants.encryptedZero, 0 ,0x0000000000000000000000000000000000000000, 0, 0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000);
            finalTransaction = RLPCoder.DecodedTX(0, 0, 0, 0x0000000000000000000000000000000000000000, searcherConstants.encryptedZero, finalData);
        }
        return (RLP.encodeTX(finalTransaction), userTransaction);
    }
}