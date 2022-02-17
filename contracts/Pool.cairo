%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import (
    assert_le, assert_nn_le, unsigned_div_rem, assert_not_zero, sqrt)
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_mul, uint256_eq,
    uint256_unsigned_div_rem, uint256_sqrt)
from contracts.utils.interfaces import IERC20, IPool

from contracts.token.ERC20_base import (
    ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
    ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
    ERC20_transfer, ERC20_transferFrom, ERC20_mint, ERC20_burn)

#
# Storage
#

@storage_var
func token0() -> (res : felt):
end

@storage_var
func token1() -> (res : felt):
end

@storage_var
func reserve0() -> (res : Uint256):
end

@storage_var
func reserve1() -> (res : Uint256):
end

@storage_var
func owner() -> (owner_address : felt):
end

@storage_var
func router() -> (router_address : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token0Address : felt, token1Address : felt):
    token0.write(value=token0Address)
    token1.write(value=token1Address)
    # name : Pool-Token
    # symbol : PTOK
    ERC20_initializer(379844936063829741888878, 1347702603, Uint256(0, 0), 1)

    return ()
end

# Getter functions
@view
func getReserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        reserve0 : Uint256, reserve1 : Uint256):
    let (_reserve0 : Uint256) = reserve0.read()
    let (_reserve1 : Uint256) = reserve1.read()

    return (_reserve0, _reserve1)
end

@view
func getToken0{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = token0.read()
    return (res)
end

@view
func getToken1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = token1.read()
    return (res)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, poolAddress : felt):
    alloc_locals

    let (_reserve0 : Uint256) = reserve0.read()
    let (_reserve1 : Uint256) = reserve1.read()

    let (_token0) = token0.read()
    let (_token1) = token1.read()

    let (balance0 : Uint256) = IERC20.balanceOf(_token0, poolAddress)
    let (balance1 : Uint256) = IERC20.balanceOf(_token1, poolAddress)

    let (amount0 : Uint256) = uint256_sub(balance0, _reserve0)
    let (amount1 : Uint256) = uint256_sub(balance1, _reserve1)

    let (_totalSupply : Uint256) = totalSupply()

    let (totalSupplyEqZero) = uint256_eq(_totalSupply, Uint256(0, 0))

    local liquidity

    if totalSupplyEqZero == 1:
        let (amount0Mulamount1 : Uint256, isOverflow_a) = uint256_mul(amount0, amount1)
        assert (isOverflow_a) = Uint256(0, 0)

        let (amountsSqrt) = uint256_sqrt(amount0Mulamount1)

        ERC20_mint(to, amountsSqrt)

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (numeratorA : Uint256, isOverflow_b) = uint256_mul(amount0, _totalSupply)
        assert (isOverflow_b) = Uint256(0, 0)

        let (numeratorB : Uint256, isOverflow_c) = uint256_mul(amount1, _totalSupply)
        assert (isOverflow_c) = Uint256(0, 0)

        let (a, _) = uint256_unsigned_div_rem(numeratorA, _reserve0)
        let (b, _) = uint256_unsigned_div_rem(numeratorB, _reserve1)

        let (aLtB) = uint256_lt(a, b)  # a < b

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

        if aLtB == 1:
            ERC20_mint(to, a)

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            ERC20_mint(to, b)

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    end

    _update(_token0, balance0, balance1)

    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, poolAddress : felt) -> (amount0 : Uint256, amount1 : Uint256):
    alloc_locals

    let (_reserve0 : Uint256) = reserve0.read()
    let (_reserve1 : Uint256) = reserve1.read()

    let (_token0) = token0.read()
    let (_token1) = token1.read()

    let (balance0 : Uint256) = IERC20.balanceOf(_token0, poolAddress)
    let (balance1 : Uint256) = IERC20.balanceOf(_token1, poolAddress)

    let (liquidity : Uint256) = balanceOf(poolAddress)

    let (_totalSupply : Uint256) = totalSupply()

    let (numeratorA : Uint256, isOverflow_a) = uint256_mul(liquidity, balance0)
    assert (isOverflow_a) = Uint256(0, 0)

    let (numeratorB : Uint256, isOverflow_b) = uint256_mul(liquidity, balance1)
    assert (isOverflow_a) = Uint256(0, 0)

    let (amount0, _) = uint256_unsigned_div_rem(numeratorA, _totalSupply)
    let (amount1, _) = uint256_unsigned_div_rem(numeratorB, _totalSupply)

    let (amount0EqZero) = uint256_eq(amount0, Uint256(0, 0))
    let (amount1EqZero) = uint256_eq(amount1, Uint256(0, 0))

    assert (amount0EqZero) = 0
    assert (amount1EqZero) = 0

    ERC20_burn(poolAddress, liquidity)

    IERC20.transfer(_token0, to, amount0)
    IERC20.transfer(_token1, to, amount1)

    let (newBalance0 : Uint256) = IERC20.balanceOf(_token0, poolAddress)
    let (newBalance1 : Uint256) = IERC20.balanceOf(_token1, poolAddress)

    _update(_token0, newBalance0, newBalance1)

    return (amount0, amount1)
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount0Out : Uint256, amount1Out : Uint256, to : felt, poolAddress : felt) -> ():
    alloc_locals

    # Get pool reserves
    let (_reserve1 : Uint256) = reserve1.read()
    let (_reserve0 : Uint256) = reserve0.read()

    # Local variables
    local tokenIn
    local tokenOut
    local amountOut : Uint256
    local reserveIn : Uint256
    local reserve_out : Uint256

    let (amount0EqZero) = uint256_eq(amount0Out, Uint256(0, 0))
    let (amount1EqZero) = uint256_eq(amount1Out, Uint256(0, 0))

    # Ensure that one of the amounts is not zero and also it is less than pool reserve
    if amount0EqZero == 1:
        assert amount1EqZero = 0

        let (_token0 : felt) = token0.read()
        let (_token1 : felt) = token1.read()

        assert tokenIn = _token0
        assert tokenOut = _token1
        assert reserveIn = _reserve0
        assert reserve_out = _reserve1
        assert amountOut = amount1Out

        let (enough_reserve) = uint256_lt(amountOut, reserve_out)
        assert enough_reserve = 1

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        assert amount1EqZero = 1

        let (_token0 : felt) = token0.read()
        let (_token1 : felt) = token1.read()

        assert tokenIn = _token1
        assert tokenOut = _token0
        assert reserveIn = _reserve1
        assert reserve_out = _reserve0
        assert amountOut = amount0Out

        let (enough_reserve) = uint256_lt(amountOut, reserve_out)
        assert enough_reserve = 1

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    # optimistically transfer output token
    IERC20.transfer(tokenOut, to, amountOut)

    let (balanceTokenIn : Uint256) = IERC20.balanceOf(tokenIn, poolAddress)
    let (balanceTokenOut : Uint256) = IERC20.balanceOf(tokenOut, poolAddress)

    let (amountIn : Uint256) = uint256_sub(balanceTokenIn, reserveIn)

    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    # Check amount in is greater than 0
    let (zeroAmountIn) = uint256_eq(amountIn, Uint256(0, 0))
    assert zeroAmountIn = 0

    # Check K formula
    let (balanceInMul1000, isOverflow_a) = uint256_mul(balanceTokenIn, Uint256(1000, 0))
    assert (isOverflow_a) = Uint256(0, 0)

    let (amountInMul3, isOverflow_b) = uint256_mul(amountIn, Uint256(3, 0))
    assert (isOverflow_b) = Uint256(0, 0)

    let (balanceInAdjusted) = uint256_sub(balanceInMul1000, amountInMul3)

    let (balanceOutAdjusted, isOverflow_c) = uint256_mul(balanceTokenOut, Uint256(1000, 0))
    assert (isOverflow_c) = Uint256(0, 0)

    let (mulAdjusted, isOverflow_d) = uint256_mul(balanceInAdjusted, balanceOutAdjusted)
    assert (isOverflow_d) = Uint256(0, 0)

    let (mulReserves, isOverflow_e) = uint256_mul(reserveIn, reserve_out)
    assert (isOverflow_e) = Uint256(0, 0)

    let (mulReservesMul10Pow6, isOverflow_f) = uint256_mul(mulReserves, Uint256(1000000, 0))
    assert (isOverflow_f) = Uint256(0, 0)

    let (kFormula) = uint256_le(mulReservesMul10Pow6, mulAdjusted)

    assert kFormula = 1

    _update(tokenIn, balanceTokenIn, balanceTokenOut)

    return ()
end

func _update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenIn : felt, balanceTokenIn : Uint256, balanceTokenOut : Uint256):
    alloc_locals

    let (_token0) = token0.read()

    if _token0 == tokenIn:
        reserve0.write(balanceTokenIn)
        reserve1.write(balanceTokenOut)
    else:
        reserve0.write(balanceTokenOut)
        reserve1.write(balanceTokenIn)
    end

    return ()
end

#
# ERC20 Functions
#

#
# Getters
#
@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC20_name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20_symbol()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalSupply : Uint256):
    let (totalSupply : Uint256) = ERC20_totalSupply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt):
    let (decimals) = ERC20_decimals()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (balance : Uint256):
    let (balance : Uint256) = ERC20_balanceOf(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (remaining : Uint256):
    let (remaining : Uint256) = ERC20_allowance(owner, spender)
    return (remaining)
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256) -> (success : felt):
    ERC20_transfer(recipient, amount)
    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    ERC20_transferFrom(sender, recipient, amount)
    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256) -> (success : felt):
    ERC20_approve(spender, amount)
    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256) -> (success : felt):
    ERC20_increaseAllowance(spender, added_value)
    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256) -> (success : felt):
    ERC20_decreaseAllowance(spender, subtracted_value)
    # Cairo equivalent to 'return (true)'
    return (1)
end
