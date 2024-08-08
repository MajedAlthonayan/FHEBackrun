// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "./RLPCoder.sol";
import "./Main.sol";


contract Backrun {

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
    function updateTokenQuantities(RLPCoder.DecodedTX memory decodedTransaction, Main.ProfitConstants memory constants) public view returns (euint64 X, euint64 Y, bytes memory searcherMethodID){
        if (decodedTransaction.data.methodID[0] == 0x18){ 
            //tokens for ETH  
            searcherMethodID = "0x7ff36ab5";
            euint64 uniswapFees = TFHE.div(TFHE.mul(decodedTransaction.data.amountIn, 3), 1000);
            euint64 amountIn_fees = TFHE.sub(decodedTransaction.data.amountIn, uniswapFees); // how much USDT was actually traded in
            euint64 token1AfterSwap = TFHE.add(constants.USDTInPool, amountIn_fees);
            euint64 token2AfterSwap = TFHE.mul(constants.EthInPool, constants.USDTInPool); 
            X = TFHE.div(token2AfterSwap, TFHE.decrypt(token1AfterSwap)); // amount of ETH after swap 
            Y = TFHE.mul(TFHE.add(constants.USDTInPool, decodedTransaction.data.amountIn), constants.EthPrecision); // USDT after swap 
        } else{ 
            // eth for tokens 
            searcherMethodID = "0x18cbafe5";
            euint64 uniswapFees = TFHE.div(TFHE.mul(decodedTransaction.value, 3), 1000);
            euint64 amountIn_fees = TFHE.sub(decodedTransaction.value, uniswapFees); // how much USDT was actually traded in
            euint64 token1AfterSwap = TFHE.add(constants.EthInPool, amountIn_fees);
            euint64 token2AfterSwap = TFHE.mul(constants.EthInPool, constants.USDTInPool);
            Y = TFHE.add(constants.EthInPool, decodedTransaction.value); // eth after swap
            X = TFHE.mul(TFHE.div(token2AfterSwap, TFHE.decrypt(token1AfterSwap)), constants.EthPrecision);  // amount of usdt after swap 
        }
        return (X, Y, searcherMethodID);
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
    function amountCalculation(Main.ProfitConstants memory constants, euint64 X, euint64 Y) public view returns(euint64 eamountIn){
        // enc version 
        euint64 evar = TFHE.sub(TFHE.mul(TFHE.mul(constants.encryptedFour, constants.maxBuyPrice), Y), TFHE.div(TFHE.mul(12, TFHE.mul(constants.maxBuyPrice, Y)), 1000));
        euint64 evar2 = TFHE.mul(X, TFHE.add(TFHE.div(TFHE.mul(9,X), 1000000), evar));
        euint64 eamountDividend = TFHE.sub(TFHE.add(esqrt(evar2), TFHE.div(TFHE.mul(X, 3), 1000)) , TFHE.mul(2, X));
        uint64 amountDivisor = (2 * constants.EthPrecision) - ((6*constants.EthPrecision) / 1000); 
        eamountIn = TFHE.div(eamountDividend , amountDivisor); 
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
    function calculateProfits(RLPCoder.DecodedTX memory decodedTransaction, euint64 X, euint64 Y, euint64 eamountIn, Main.ProfitConstants memory constants) public view returns(euint64 profit, euint64){
        //enc version
        euint64 x_after_fee;
        euint64 y_after;
        if (decodedTransaction.data.methodID[0] == 0x18){ 
            Y = TFHE.div(Y, constants.EthPrecision);
            x_after_fee = TFHE.sub(TFHE.add(X, eamountIn) ,TFHE.div(TFHE.mul(eamountIn, 3), 1000));
            y_after = TFHE.div(TFHE.mul(X,Y), TFHE.decrypt(x_after_fee));
            profit = TFHE.mul(TFHE.sub(constants.minSellPrice, constants.maxBuyPrice), TFHE.sub(Y, y_after));
        }else{
            X = TFHE.div(X, constants.EthPrecision);
            x_after_fee = TFHE.sub(TFHE.add(X, eamountIn) ,TFHE.div(TFHE.mul(eamountIn, 3), 1000));
            y_after = TFHE.div(TFHE.mul(X,Y), TFHE.decrypt(x_after_fee));
            profit = TFHE.div(TFHE.mul(TFHE.sub(constants.minSellPrice, constants.maxBuyPrice), TFHE.sub(Y, y_after)), constants.EthPrecision);
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
            // Take care of easy edge cases when a == 0 or a == 1
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

            xn = (3 * xn) >> 1; // ε_0 := | x_0 - sqrt(a) | ≤ 2**(e-2)
 
            xn = (xn + b / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + b / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + b / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + b / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + b / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + b / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72

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
