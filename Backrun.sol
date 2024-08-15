// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "./RLPCoder.sol";
// import "./lib/TFHE.sol";
import "./Main.sol";


contract Backrun {

    event debug(string, euint64);
    event debug2(string, uint256);
    event debugBytes(string, bytes);
    /*
        * 
        * @dev This function updates the quantities of the pool based on the trade that was peformed by the user. 
        * @param {decodedTransaction} A struct containing the fields of the user's transaction.  
        * @param {constants} The searcher's strategy.
        * @return {X} The quantity of the token being traded in by the searcher. 
        * @return {Y} The quantity of the token being received by the searcher.
        * @return {searcherMethodID} The method ID of the uniswapV2 method that is to be used by the searcher. 
        *
    */
    function updateTokenQuantities(euint64 amountIn, euint64 value, bytes memory methodID, euint64 EthInPool, euint64 USDTInPool) public view returns (euint64, euint64, bytes memory){
        bytes memory searchersMethodID;
        euint64 token1;
        euint64 token2 ;

        if (methodID[0] == 0x18){ 
            // Tokens For ETH  
            searchersMethodID = hex"7ff36ab5";
            euint64 uniswapFees = TFHE.div(TFHE.mul(amountIn, 3), 1000);
            euint64 amountIn_fees = TFHE.sub(amountIn, uniswapFees); // how much USDT was actually traded in
            euint64 token1AfterSwap = TFHE.add(USDTInPool, amountIn_fees);
            token2 = TFHE.add(USDTInPool, amountIn); // USDT after swap 
            euint64 newEthInPool = TFHE.mul(EthInPool, 1000000);
            token1 = TFHE.div(newEthInPool, TFHE.decrypt(token1AfterSwap)); // eth after swap
            token1 = TFHE.div(TFHE.mul(token1, USDTInPool), 1000000); // undoing earlier multiplication
        } else{ 
            // Eth For Tokens 
            searchersMethodID = hex"18cbafe5";
            euint64 newValue = TFHE.div(value, 1000000000000);
            euint64 uniswapFees = TFHE.div(TFHE.mul(newValue, 3), 1000);
            euint64 amountIn_fees = TFHE.sub(newValue, uniswapFees); // how much USDT was actually traded in
            euint64 token1AfterSwap = TFHE.add(EthInPool, amountIn_fees);
            token2 = TFHE.add(EthInPool, newValue); // eth after swap
            euint64 newEthInPool = TFHE.mul(EthInPool, 1000000); // x 1000000 to help with int division
            token1 = TFHE.div(newEthInPool,TFHE.decrypt(token1AfterSwap)); // usdt after swap
            token1 = TFHE.div(TFHE.mul(token1, USDTInPool), 1000000); // undoing earlier multiplication   
        }
        return (token1, token2, searchersMethodID);
    }

    /*
        * 
        * @dev Calculates the optimal amount the searcher should trade in. 
        * @param {constants} The searcher's strategy
        * @param {X} The quantity of the token being traded in the pool. 
        * @param {Y} The quantity of the token being traded out the pool. 
        * @return {eamountIn} The optimal amount to trade in.
        *
    */
    function amountCalculation(Main.ProfitConstants memory searcherConstants, euint64 X, euint64 Y) public view returns(euint64 eamountIn){
        euint64 evar = TFHE.sub(TFHE.mul(TFHE.mul(searcherConstants.encryptedFour, searcherConstants.maxBuyPrice), Y), TFHE.div(TFHE.mul(12, TFHE.mul(searcherConstants.maxBuyPrice, Y)), 1000));
        euint64 evar2 = TFHE.mul(X, TFHE.add(TFHE.div(TFHE.mul(9,X), 1000000), evar));
        euint64 eamountDividend = TFHE.sub(TFHE.add(esqrt(evar2), TFHE.div(TFHE.mul(X, 3), 1000)) , TFHE.mul(2, X));
        eamountIn = TFHE.div(eamountDividend , 1000); 
        eamountIn = TFHE.mul(eamountDividend , 1994); 
        return eamountIn;
    }

    /*
        * 
        * @dev Calculates the profit of the searcher based on the amount they traded in. 
        * @param {decodedTransaction} The decoded user transaction
        * @param {X} The quantity of the token being traded in the pool. 
        * @param {Y} The quantity of the token being traded out the pool. 
        * @param {eamountIn} The amount that the searcher has traded in.
        * @param {constants} The searcher's strategy.
        * @return {profit} The profit resulting from the trade. 
        *
    */
    function calculateProfits(RLPCoder.DecodedTX memory decodedTransaction, euint64 X, euint64 Y, euint64 eamountIn, Main.ProfitConstants memory searcherConstants) public view returns(euint64 profit, euint64){
        euint64 x_after_fee;
        euint64 y_after;
        if (decodedTransaction.data.methodID[0] == 0x18){ 
            // Y = TFHE.div(Y, searcherConstants.EthPrecision);
            x_after_fee = TFHE.sub(TFHE.add(X, eamountIn) ,TFHE.div(TFHE.mul(eamountIn, 3), 1000));
            uint64 xx =  TFHE.decrypt(x_after_fee);
            y_after = TFHE.div(TFHE.mul(X,Y), xx);
            profit = TFHE.mul(TFHE.sub(searcherConstants.minSellPrice, searcherConstants.maxBuyPrice), TFHE.sub(Y, y_after));
        }else{
            // X = TFHE.div(X, searcherConstants.EthPrecision);
            x_after_fee = TFHE.sub(TFHE.add(X, eamountIn) ,TFHE.div(TFHE.mul(eamountIn, 3), 1000));
            uint64 xx =  TFHE.decrypt(x_after_fee);
            y_after = TFHE.div(TFHE.mul(X,Y), xx);
            profit = TFHE.mul(TFHE.sub(searcherConstants.minSellPrice, searcherConstants.maxBuyPrice), TFHE.sub(Y, y_after));
        }
        return (profit, TFHE.sub(Y, y_after)); 
    }

    /*
        * 
        * @dev Uses the Newton Method to calculate the square root of an encrypted integer. 
        * @param {a} The radicand 
        * @return The square root. 
        *
    */
    function esqrt(euint64 a) public view returns (euint64) {
        unchecked {
            uint256 b = TFHE.decrypt(a);

            if (b <= 1) {
                return TFHE.asEuint64(b);
            }

            uint256 aa = b;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {aa >>= 128; xn <<= 64;}
            if (aa >= (1 << 64)) {aa >>= 64; xn <<= 32;}
            if (aa >= (1 << 32)) {aa >>= 32; xn <<= 16;}
            if (aa >= (1 << 16)) {aa >>= 16; xn <<= 8;}
            if (aa >= (1 << 8)) {aa >>= 8; xn <<= 4;}
            if (aa >= (1 << 4)) {aa >>= 4; xn <<= 2;}
            if (aa >= (1 << 2)) {xn <<= 1;}

            xn = (3 * xn) >> 1; 
 
            xn = (xn + b / xn) >> 1;
            xn = (xn + b / xn) >> 1; 
            xn = (xn + b / xn) >> 1; 
            xn = (xn + b / xn) >> 1; 
            xn = (xn + b / xn) >> 1; 
            xn = (xn + b / xn) >> 1; 

            uint256 finally = xn - toUint(xn > b / xn);
            return TFHE.asEuint64(finally);
        }
    }
    
    /*
        * 
        * @dev Helper function to convert booleans to integers. 
        * @param {b} boolean to be converted to integer.  
        * @return {u} integer representation of the boolean.
        *
    */
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly {
            u := iszero(iszero(b))
        }
    }



}
