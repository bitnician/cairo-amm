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

    func mint(to : felt, amountsSqrt : Uint256, poolAddress : felt):
    end

    func burn(to : felt, poolAddress : felt) -> (amount0 : Uint256, amount1 : Uint256):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256):
    end

    func swap(amount0Out : Uint256, amount1Out : Uint256, to : felt, poolAddress : felt) -> ():
    end

    func getReserves() -> (reserve0 : Uint256, reserve1 : Uint256):
    end
end

@contract_interface
namespace IRouter:
    func verifyPoolIsWhitelisted(poolAddress : felt):
    end

    func getPoolAddress(token_a_address : felt, token_b_address : felt) -> (poolAddress : felt):
    end

    func whitelistPool(poolAddress) -> ():
    end

    func initLiquidity(
            sender : felt, token_a_address : felt, token_b_address : felt,
            amount_a_desired : Uint256, amount_b_desired : Uint256, amountsSqrt : Uint256) -> ():
    end

    func addLiquidity(
            token_a_address : felt, token_b_address : felt, amount_a_desired : Uint256,
            amount_b_desired : Uint256, amount_a_min : Uint256, amount_b_min : Uint256) -> ():
    end

    func removeLiquidity(
            token_a_address : felt, token_b_address : felt, liquidity_amount : Uint256,
            amount_a_min : Uint256, amount_b_min : Uint256, to : felt) -> ():
    end

    func getAmountIn(tokenInAddress : felt, tokenOutAddress : felt, amountOut : Uint256) -> (
            amountIn : Uint256):
    end

    func getAmountOut(tokenInAddress : felt, tokenOutAddress : felt, amountIn : Uint256) -> (
            amountOut : Uint256):
    end

    func exactInput(
            tokenInAddress : felt, tokenOutAddress : felt, amountIn : Uint256,
            amountOutMin : Uint256) -> ():
    end

    func exactOutput(
            tokenInAddress : felt, tokenOutAddress : felt, amountOut : Uint256,
            amountIn_max : Uint256) -> ():
    end
end
