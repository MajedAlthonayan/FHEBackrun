// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./RLPCoder.sol";
import "./Backrun.sol";

contract Main{


    RLPCoder public RLP;
    Backrun public backrun;
    bool valid; 

    struct ProfitConstants{
        euint64 EthInPool; // from searcher
        euint64 USDTInPool; // from searcher
        uint64 EthPrecision; //number of decimals for WETH (fixed)
        euint64 maxBuyPrice; // max buy price from searcher
        euint64 minSellPrice; // min sell price from searcher
        euint64 encryptedFour;
        euint64 encryptedZero;
        euint64 amountIn;
        euint64 amountOut;
        euint64 profit;
        euint64 X;
        euint64 Y;
        bytes searcherMethodID;
    }
        RLPCoder.DecodedTX decodedTransaction;
        ProfitConstants searcherConstants;
        RLPCoder.Data finalData;
        RLPCoder.DecodedTX finalTransaction ;
        // euint64 amountIn;
        // euint64 profit;
        // euint64 X;
        // euint64 Y;
        // bytes searcherMethodID;
        // euint64 amountOut;
    event debug(string, bool);
    event debug2(string, euint64);
    event debug3(string, bytes);
    event debug4(string, uint256);
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

        decodedTransaction = RLP.decodeTX(userTransaction);
        searcherConstants = ProfitConstants(TFHE.asEuint64(EthInPool), TFHE.asEuint64(USDTInPool), 1000000000000000000, TFHE.asEuint64(maxBuyPrice), TFHE.asEuint64(minSellPrice), TFHE.asEuint64(4), TFHE.asEuint64(0), TFHE.asEuint64(0),TFHE.asEuint64(0),TFHE.asEuint64(0),TFHE.asEuint64(0),TFHE.asEuint64(0), "0x0"); // change
        
        //User transaction comparisons
        if(decodedTransaction.to == 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D && decodedTransaction.data.deadline >= 1669870000 && decodedTransaction.data.addressLength == 2){
            valid = true;
            
            // update token quantites
            (searcherConstants.X, searcherConstants.Y, searcherConstants.searcherMethodID) = backrun.updateTokenQuantities(decodedTransaction, searcherConstants); // 6,182,097 gas 

            // calculating amount in 
            searcherConstants.amountIn = backrun.amountCalculation(searcherConstants, searcherConstants.X, searcherConstants.Y); // 7,719,044 gas cost TODO: change
            
            // calculating profits 
            (searcherConstants.profit, searcherConstants.amountOut) = backrun.calculateProfits(decodedTransaction, searcherConstants.X, searcherConstants.Y, searcherConstants.amountIn, searcherConstants); // 5,384,859 gas cost change 
            
            // Searcher transaction comparisons 
            if(TFHE.decrypt(TFHE.or(TFHE.lt(searcherConstants.amountIn, 0) , TFHE.lt(searcherConstants.profit, 2)))){
                valid =  false;
            }
        
        }else{ 
            valid = false;
        }
        

        if(valid == true){
            if (searcherConstants.searcherMethodID[0] == 0x18){
                // Tokens For Eth 
                finalData = RLPCoder.Data(searcherConstants.searcherMethodID, searcherConstants.amountIn, searcherConstants.amountOut, 160 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, searcherConstants.encryptedZero, finalData);
            }else{
                // Eth For Tokens
                finalData = RLPCoder.Data(searcherConstants.searcherMethodID, searcherConstants.encryptedZero, searcherConstants.amountOut, 128 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, searcherConstants.amountIn, finalData);
            }
        }else{
            // Return 0 transaction
            finalData = RLPCoder.Data('0', searcherConstants.encryptedZero, searcherConstants.encryptedZero, 0 ,0x0000000000000000000000000000000000000000, 0, 0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000);
            finalTransaction = RLPCoder.DecodedTX(0, 0, 0, 0x0000000000000000000000000000000000000000, searcherConstants.encryptedZero, finalData);
        }

        return (RLP.encodeTX(finalTransaction));
    } 




    function BackrunTest1(bytes memory userTransaction, uint256 EthInPool, uint256 USDTInPool, uint32 maxBuyPrice, uint32 minSellPrice) public returns(bool){
        RLP = new RLPCoder();
        backrun = new Backrun();

        decodedTransaction = RLP.decodeTX(userTransaction);
        // searcherConstants = ProfitConstants(TFHE.asEuint64(EthInPool), TFHE.asEuint64(USDTInPool), 1000000000000000000, TFHE.asEuint64(maxBuyPrice), TFHE.asEuint64(minSellPrice), TFHE.asEuint64(4), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), "0x00000000"); 
        searcherConstants = ProfitConstants(TFHE.asEuint64(EthInPool), TFHE.asEuint64(USDTInPool), 1000000000000, TFHE.asEuint64(maxBuyPrice), TFHE.asEuint64(minSellPrice), TFHE.asEuint64(4), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), TFHE.asEuint64(0), "0x00000000"); 
        
        //User transaction comparisons
        if(decodedTransaction.to == 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D && decodedTransaction.data.deadline >= 1669870000 && decodedTransaction.data.addressLength == 2){
            valid = true;
            // update token quantites
            (searcherConstants.X, searcherConstants.Y, searcherConstants.searcherMethodID) = backrun.updateTokenQuantities(decodedTransaction, searcherConstants); 
        }else{
            valid = false;
        }
        return valid;
        
    }

    function BackrunTest2() public returns(bool){

        
        //User transaction comparisons
        if(decodedTransaction.to == 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D && decodedTransaction.data.deadline >= 1669870000 && decodedTransaction.data.addressLength == 2){
            valid = true;            
            // calculating amount in 
            searcherConstants.amountIn = backrun.amountCalculation(searcherConstants, searcherConstants.X, searcherConstants.Y); 

        }else{
            valid = false;
        }
        return valid;
        
    }

    function BackrunTest3() public returns(bool){
        //User transaction comparisons
        if(decodedTransaction.to == 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D && decodedTransaction.data.deadline >= 1669870000 && decodedTransaction.data.addressLength == 2){
            valid = true;
            // calculating profits 
            (searcherConstants.profit, searcherConstants.amountOut) = backrun.calculateProfits(decodedTransaction, searcherConstants.X, searcherConstants.Y, searcherConstants.amountIn, searcherConstants); 

            // Searcher transaction comparisons 
            if(TFHE.decrypt(TFHE.or(TFHE.lt(searcherConstants.amountIn, 0) , TFHE.lt(searcherConstants.profit, 2)))){
                valid =  false;
            }
        }else{
            valid = false;
        }
        return valid;
    }

    function BackrunTest4(uint8 searcherNonce, address searcherAddress) public returns(bytes memory){

        if(valid == true){
            if (searcherConstants.searcherMethodID[0] == 0x18){
                // Tokens For Eth 
                finalData = RLPCoder.Data(searcherConstants.searcherMethodID, searcherConstants.amountIn, searcherConstants.amountOut, 160 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, searcherConstants.encryptedZero, finalData);
            }else{
                // Eth For Tokens
                finalData = RLPCoder.Data(searcherConstants.searcherMethodID, searcherConstants.encryptedZero, searcherConstants.amountOut, 128 ,searcherAddress, (block.timestamp + 600), 2, decodedTransaction.data.token2, decodedTransaction.data.token1);
                finalTransaction = RLPCoder.DecodedTX(searcherNonce, decodedTransaction.gasPrice, decodedTransaction.gasLimit, decodedTransaction.to, searcherConstants.amountIn, finalData);
            }
        }else{
            // Return 0 transaction
            finalData = RLPCoder.Data('0', searcherConstants.encryptedZero, searcherConstants.encryptedZero, 0 ,0x0000000000000000000000000000000000000000, 0, 0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000);
            finalTransaction = RLPCoder.DecodedTX(0, 0, 0, 0x0000000000000000000000000000000000000000, searcherConstants.encryptedZero, finalData);
        }
        emit debug3("Final TX", RLP.encodeTX(finalTransaction));
        return (RLP.encodeTX(finalTransaction));
        
    }
}