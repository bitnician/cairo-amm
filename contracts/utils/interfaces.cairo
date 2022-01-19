%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func allowance(owner : felt, spender : felt) -> (remaining : Uint256):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end

    func approve(spender : felt, amount : Uint256) -> (success : felt):
    end
end

@contract_interface
namespace IPool:
    func getToken0() -> (res : felt):
    end

    func getToken1() -> (res : felt):
    end

    func mint(to : felt, amountsSqrt : Uint256, pool : felt):
    end

    func burn(to : felt, pool : felt) -> (amount0 : Uint256, amount1 : Uint256):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256):
    end

    func swap(amount0Out : Uint256, amount1Out : Uint256, to : felt, pool : felt) -> ():
    end

    func getReserves() -> (reserve0 : Uint256, reserve1 : Uint256):
    end
end

@contract_interface
namespace IRouter:
    func getPoolReserve(pool : felt, desiredToken : felt) -> (reserve : Uint256):
    end

    func getPoolAddress(tokenA : felt, tokenB : felt) -> (pool : felt):
    end

    func whitelistPool(pool) -> ():
    end

    func initLiquidity(
            to : felt, tokenA : felt, tokenB : felt, amountADesired : Uint256,
            amountBDesired : Uint256, amountsSqrt : Uint256) -> ():
    end

    func addLiquidity(
            tokenA : felt, tokenB : felt, amountADesired : Uint256, amountBDesired : Uint256,
            amountAMin : Uint256, amountBMin : Uint256) -> ():
    end

    func removeLiquidity(
            tokenA : felt, tokenB : felt, liquidityAmount : Uint256, amountAMin : Uint256,
            amountBMin : Uint256, to : felt) -> ():
    end

    func getAmountIn(tokenIn : felt, tokenOut : felt, amountOut : Uint256) -> (amountIn : Uint256):
    end

    func getAmountOut(tokenIn : felt, tokenOut : felt, amountIn : Uint256) -> (amountOut : Uint256):
    end

    func exactInput(
            tokenIn : felt, tokenOut : felt, amountIn : Uint256, amountOutMin : Uint256) -> ():
    end

    func exactOutput(
            tokenIn : felt, tokenOut : felt, amountOut : Uint256, amountIn_max : Uint256) -> ():
    end
end
