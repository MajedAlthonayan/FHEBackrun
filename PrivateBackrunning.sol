// Backrunning Private Transactions using fhEVM

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./TXDecoder.sol";
import "fhevm/lib/TFHE.sol";




contract Backrun{

    // TXDecoder private decoder;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    TXDecoder public txDecoder;


    struct ProfitConstants{
        //:: 3 / 1000 = 0.3% Uniswap Fee
        uint64 feeDividend; //fixed 3 
        uint64 feeDivisor; // fixed 1000
        uint256 EthInPool; // from searcher
        uint256 USDTInPool; // from searcher
        uint64 EthPrecision; //number of decimals for WETH (fixed)
        uint256 constantForAmountIn; //constant for computing amountIN (2) - used as acc integer in calculation
        uint256 maxBuyPrice; // max buy price from searcher
        uint256 constantForAmountIn2; // constant for computing amountIN (4) - used as acc integer in calculation
        uint256 minSellPrice; // min sell price from searcher
        uint256 costOfArbitrage; // fixed 2 USDT
        uint256 minProfit; // fixed 0 
    }

    event debug(string message,uint256 x);

    function BackrunTX(bytes memory userTransaction, uint256 EthInPool, uint256 USDTInPool, uint256 maxBuyPrice, uint256 minSellPrice) public returns(uint256 profit){

        txDecoder = new TXDecoder();
        TXDecoder.DecodedTX memory decodedTransaction = txDecoder.decodeTX(userTransaction);

        ProfitConstants memory constants = ProfitConstants(3, 1000, EthInPool, USDTInPool, 1000000000000000000, 2, maxBuyPrice, 4, minSellPrice, 2000000, 0);

        //unenc version
        uint256 x;
        uint256 y;


        
        // unenc version
        if (decodedTransaction.data.methodID[0] == 0x18){ //tokens for ETH  // TODO change back to 0x18
            profit = 100;        
            //TODO
        } else{ // eth for tokens 
            // fee calc
            uint256 uniswapFeesTwo = ((decodedTransaction.value) * 3) / 1000;
            uint256 amountIn_fees = ((decodedTransaction.value) - uniswapFeesTwo); // how much was actually traded in
            emit debug("Amount In fees", amountIn_fees);
            // just for fee calculation
            uint256 token1AfterSwap = EthInPool + amountIn_fees; // test
            emit debug("Eth after swap", token1AfterSwap);
            uint256 token2AfterSwap = EthInPool * USDTInPool; 

            x = (token2AfterSwap / token1AfterSwap); // amount of usdt after swap - using x * y = k :: (only plaintext divisor) 
            y = EthInPool + (decodedTransaction.value);


            // ETH for real now!
            x = x * constants.EthPrecision;
        }
        emit debug("x", x);
        emit debug("y", y);


        // unenc version 
        uint256 var1 = x * (((9*x) / 1000000) + ((4 * maxBuyPrice * y) - ((12 * maxBuyPrice * y) / 1000)));
        uint256 amountDividend = (sqrt(var1) + ( (x*3) /1000)) - (2*x);
        emit debug("Amount Divisor", amountDividend);

  
        

        //unenc version 
        uint64 amountDivisor = ((2 * constants.EthPrecision) - ((6 * constants.EthPrecision) / 1000));
        emit debug("Amount Divisor", amountDivisor);
        uint256 amountIn = amountDividend / amountDivisor; // ok because plaintext divisor
        emit debug("Amount", amountIn);

        // unenc version 
        x = x / constants.EthPrecision;
        uint256 x_after_fee = (x + amountIn) - ((amountIn * 3) / 1000);
        emit debug("x after fee", x_after_fee);
        uint256 y_after = ((x * y) / x_after_fee);
        emit debug("y_after", y_after);
        uint256 amountOut = y - y_after; 
        emit debug("amount Out", amountOut);
        profit = (((minSellPrice - maxBuyPrice) * amountOut) / constants.EthPrecision);
        if(profit <= 2){
            profit = 0;
        }else{
            profit = profit - constants.costOfArbitrage;
        }
        emit debug("Profit", profit);



        return profit;
    } 


    function sqrt(uint256 a) internal pure returns (uint256) {
        unchecked {
            // Take care of easy edge cases when a == 0 or a == 1
            if (a <= 1) {
                return a;
            }


            uint256 aa = a;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {
                aa >>= 128;
                xn <<= 64;
            }
            if (aa >= (1 << 64)) {
                aa >>= 64;
                xn <<= 32;
            }
            if (aa >= (1 << 32)) {
                aa >>= 32;
                xn <<= 16;
            }
            if (aa >= (1 << 16)) {
                aa >>= 16;
                xn <<= 8;
            }
            if (aa >= (1 << 8)) {
                aa >>= 8;
                xn <<= 4;
            }
            if (aa >= (1 << 4)) {
                aa >>= 4;
                xn <<= 2;
            }
            if (aa >= (1 << 2)) {
                xn <<= 1;
            }


            xn = (xn + a / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + a / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + a / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + a / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + a / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + a / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72
        return xn - toUint(xn > a / xn);
        }
    }
    function toUint(bool b) internal pure returns (uint256 u) {
        /// @solidity memory-safe-assembly
        assembly {
            u := iszero(iszero(b))
        }
    }



}