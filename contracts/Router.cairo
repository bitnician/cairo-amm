%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn_le, is_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.syscalls import get_caller_address, get_tx_signature
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single)
from starkware.cairo.common.registers import get_fp_and_pc
from contracts.utils.interfaces import IERC20, IPool
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_mul, uint256_eq,
    uint256_unsigned_div_rem)

@event
func poolWhitelisted(pool : felt):
end

@event
func liquidityAdded(
        to : felt, tokenA : felt, tokenB : felt, amountA : Uint256, amountB : Uint256, pool : felt):
end

@event
func liquidityRemoved(
        to : felt, tokenA : felt, tokenB : felt, amountA : Uint256, amountB : Uint256, pool : felt):
end

@event
func swapped(
        swapper : felt, tokenIn : felt, tokenOut : felt, amountIn : Uint256, amountOut : Uint256,
        pool : felt):
end

@storage_var
func owner() -> (owner_address : felt):
end

@storage_var
func whitlistedPool(pool : felt) -> (res : felt):
end

@storage_var
func poolAddress(token0 : felt, token1 : felt) -> (pool : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner_address : felt):
    owner.write(value=owner_address)
    return ()
end

# @notice It checks if the caller is the owner of the contract.
# @returns the owner address if the caller is the owner, otherwise it throws an error.
func onlyOwner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (_owner):
    alloc_locals
    let (local caller) = get_caller_address()
    let (_owner) = owner.read()
    assert caller = _owner
    return (_owner)
end

# @notice It accepts a pool contract address as argument and check if the given address is whitelisted.
# @param pool the address of the pool contract.
# @dev It throws an error if the given address is not whitelisted.
@view
func onlyWhitelistedPool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool : felt) -> ():
    let (address) = whitlistedPool.read(pool)
    assert_not_zero(address)

    return ()
end

# @notice It accepts the token0 and token1 addresses as arguments and returns the pool contract address.
# @param token0 : the token0 address
# @param token1 : the token1 address
# @returns the pool contract address
# @dev It return 0 if the pool contract address is not found.
@view
func getPoolAddress{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenA : felt, tokenB : felt) -> (address : felt):
    let (address : felt) = poolAddress.read(tokenA, tokenB)

    return (address)
end

# @notice Given some asset amount and reserves, returns an amount of the other asset representing
# equivalent value.
# @param amountA : the amount of asset A
# @param reserveA : the reserve of asset A
# @param reserveB : the reserve of asset B
# @returns amountB : the amount of asset B
@view
func quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountA : Uint256, reserveA : Uint256, reserveB : Uint256) -> (amountB : Uint256):
    alloc_locals
    let (amountAIsZero) = uint256_eq(amountA, Uint256(0, 0))
    let (reserveAIsZero) = uint256_eq(reserveA, Uint256(0, 0))
    let (reserveBIsZero) = uint256_eq(reserveB, Uint256(0, 0))

    assert amountAIsZero = 0
    assert reserveAIsZero = 0
    assert reserveBIsZero = 0

    let (amountAMulReserveB, isOverflow) = uint256_mul(amountA, reserveB)
    assert (isOverflow) = Uint256(0, 0)

    let (amountB, _) = uint256_unsigned_div_rem(amountAMulReserveB, reserveA)

    return (amountB)
end

# @notice It whitelists a pool contract address.
# @param pool : the address of the pool contract.
# @dev It throws an error if the given address is already whitelisted OR the caller is not Owner.
@external
func whitelistPool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(pool) -> ():
    alloc_locals
    onlyOwner()

    let (token0) = IPool.getToken0(pool)
    let (token1) = IPool.getToken1(pool)

    # tokens are registered in the pool
    assert_not_zero(token0)
    assert_not_zero(token1)

    # pool is not whitelisted yet
    let (res) = whitlistedPool.read(pool)
    assert res = 0

    whitlistedPool.write(pool, 1)

    poolAddress.write(token0, token1, pool)
    poolAddress.write(token1, token0, pool)

    poolWhitelisted.emit(pool)

    return ()
end

# @notice It add the first amounts of liquidity to the pool.
# @param to : the address that receives lp tokens
# @param tokenA : the address of the token0
# @param tokenB : the address of the token1
# @param amountA : the amount of token0
# @param amountB : the amount of token1
# @param amountsSqrt : square_root(amountADesired * amountBDesired)
# @dev It throws an error if the caller is not the owner OR the pool is not whitelisted
# OR the amount is not valid OR the pool has already some amounts of liquidity.
@external
func initLiquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, tokenA : felt, tokenB : felt, amountADesired : Uint256, amountBDesired : Uint256,
        amountsSqrt : Uint256) -> ():
    alloc_locals
    let (_owner) = onlyOwner()

    let (desiredAmountsMultiplied, isOverflow) = uint256_mul(amountADesired, amountBDesired)
    assert (isOverflow) = Uint256(0, 0)

    let (poolAddress) = getPoolAddress(tokenA, tokenB)

    onlyWhitelistedPool(poolAddress)

    let (local tokenAreserve : Uint256) = getPoolReserve(poolAddress, tokenA)

    let (local tokenBReserve : Uint256) = getPoolReserve(poolAddress, tokenB)

    # Check to see if the pool balance is zero.
    let (reserveAIszero) = uint256_eq(tokenAreserve, Uint256(0, 0))
    let (reserveBIszero) = uint256_eq(tokenBReserve, Uint256(0, 0))

    assert reserveAIszero = 1
    assert reserveBIszero = 1

    IERC20.transferFrom(tokenA, to, poolAddress, amountADesired)
    IERC20.transferFrom(tokenB, to, poolAddress, amountBDesired)

    IPool.mint(poolAddress, _owner, amountsSqrt, poolAddress)

    liquidityAdded.emit(to, tokenA, tokenB, amountADesired, amountBDesired, poolAddress)
    return ()
end

# @notice It adds liquidity to the pool. can be called by anyone
# @param tokenA : the address of the token0
# @param tokenB : the address of the token1
# @param amountADesired : The amount of tokenA to add as liquidity if
# the B/A price is <= amountBDesired/amountADesired (A depreciates).
# @param amountBDesired : The amount of tokenB to add as liquidity if
# the A/B price is <= amountADesired/amountBDesired (B depreciates).
# @param amountAMin : Bounds the extent to which the B/A price can go up before
# the transaction reverts. Must be <= amountADesired.
# @param amountBMin : Bounds the extent to which the A/B price can go up before
# the transaction reverts. Must be <= amountBDesired.
@external
func addLiquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenA : felt, tokenB : felt, amountADesired : Uint256, amountBDesired : Uint256,
        amountAMin : Uint256, amountBMin : Uint256) -> ():
    alloc_locals

    let (local caller) = get_caller_address()

    let (poolAddress) = getPoolAddress(tokenA, tokenB)

    onlyWhitelistedPool(poolAddress)

    let (local tokenAreserve : Uint256) = getPoolReserve(poolAddress, tokenA)
    let (local tokenBReserve : Uint256) = getPoolReserve(poolAddress, tokenB)

    # Check to see if the pool balance is not zero.
    let (reserveAIszero) = uint256_eq(tokenAreserve, Uint256(0, 0))
    let (reserveBIszero) = uint256_eq(tokenBReserve, Uint256(0, 0))

    assert reserveAIszero = 0
    assert reserveBIszero = 0

    local amountA : Uint256
    local amountB : Uint256

    let (amountBOptimal : Uint256) = quote(amountADesired, tokenAreserve, tokenBReserve)
    let (amountAOptimal : Uint256) = quote(amountBDesired, tokenBReserve, tokenAreserve)

    let (amountBIsOptimal) = uint256_le(amountBOptimal, amountBDesired)

    if amountBIsOptimal == 1:
        let (enoughAmountB) = uint256_le(amountBMin, amountBOptimal)
        assert enoughAmountB = 1

        assert amountA = amountADesired
        assert amountB = amountBOptimal

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (amountAIsOptimal) = uint256_le(amountAOptimal, amountADesired)
        assert amountAIsOptimal = 1

        let (enoughAmountA) = uint256_le(amountAMin, amountAOptimal)
        assert enoughAmountA = 1

        assert amountA = amountAOptimal
        assert amountB = amountBDesired

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    IERC20.transferFrom(tokenA, caller, poolAddress, amountA)
    IERC20.transferFrom(tokenB, caller, poolAddress, amountB)

    IPool.mint(poolAddress, caller, Uint256(0, 0), poolAddress)

    liquidityAdded.emit(caller, tokenA, tokenB, amountA, amountB, poolAddress)

    return ()
end

# @notice It removes liquidity from the pool. can be called by anyone
# @param tokenA : the address of the token0
# @param tokenB : the address of the token1
# @param liquidityAmount : The amount of liquidity tokens to remove.
# @param amountAMin : The minimum amount of tokenA that must be received for
# the transaction not to revert.
# @param amountBMin : The minimum amount of tokenB that must be received for
# the transaction not to revert.
# @param to : Recipient of the underlying assets.
@external
func removeLiquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenA : felt, tokenB : felt, liquidityAmount : Uint256, amountAMin : Uint256,
        amountBMin : Uint256, to : felt) -> ():
    alloc_locals

    let (local caller) = get_caller_address()

    let (poolAddress) = getPoolAddress(tokenA, tokenB)

    onlyWhitelistedPool(poolAddress)

    IPool.transferFrom(poolAddress, caller, poolAddress, liquidityAmount)
    let (amount0 : Uint256, amount1 : Uint256) = IPool.burn(poolAddress, to, poolAddress)

    local amountA : Uint256
    local amountB : Uint256

    let (token0) = IPool.getToken0(poolAddress)

    if token0 == tokenA:
        assert amountA = amount0
        assert amountB = amount1
    else:
        assert amountA = amount1
        assert amountB = amount0
    end

    let (enoughAmountA) = uint256_le(amountAMin, amountA)
    let (enoughAmountB) = uint256_le(amountBMin, amountB)

    assert enoughAmountA = 1
    assert enoughAmountB = 1

    liquidityRemoved.emit(caller, tokenA, tokenB, amountA, amountB, poolAddress)

    return ()
end

# @notice Getting the pool reserve of token.
# @param poolAddress : address of the pool contract
# @param desiredToken : address of the token
# @return The reserve of the other token of pool.
func getPoolReserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool : felt, desiredToken : felt) -> (reserve : Uint256):
    let (token0) = IPool.getToken0(pool)

    let (token0Reserve : Uint256, token1Reserve : Uint256) = IPool.getReserves(pool)

    if desiredToken == token0:
        return (token0Reserve)
    else:
        return (token1Reserve)
    end
end

# @notice Given an output asset amount and token addresses, calculates all
# preceding minimum input token amounts.
# @param tokenIn : address of the input token
# @param tokenOut : address of the output token
# @param amountOut : the amount of the output token
# @return The minimum input token amounts.
@view
func getAmountIn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenIn : felt, tokenOut : felt, amountOut : Uint256) -> (amountIn : Uint256):
    alloc_locals

    let (pool) = getPoolAddress(tokenIn, tokenOut)

    onlyWhitelistedPool(pool)

    let (reserveOut : Uint256) = getPoolReserve(pool, tokenOut)
    let (reserveIn : Uint256) = getPoolReserve(pool, tokenIn)

    let (enoughReserveIn) = uint256_lt(Uint256(0, 0), reserveIn)
    let (enoughReserveOut) = uint256_lt(Uint256(0, 0), reserveOut)

    assert (enoughReserveIn) = 1
    assert (enoughReserveOut) = 1

    let (reserveInMulAmountOut, _) = uint256_mul(reserveIn, amountOut)
    let (numerator, isOverflow_a) = uint256_mul(reserveInMulAmountOut, Uint256(1000, 0))
    assert (isOverflow_a) = Uint256(0, 0)

    let (reserveOutSubAmountOut) = uint256_sub(reserveOut, amountOut)
    let (denominator, isOverflow_b) = uint256_mul(reserveOutSubAmountOut, Uint256(997, 0))
    assert (isOverflow_b) = Uint256(0, 0)

    let (amountIn, _) = uint256_unsigned_div_rem(numerator, denominator)

    let (res, isOverflow_c) = uint256_add(amountIn, Uint256(1, 0))
    assert (isOverflow_c) = 0

    return (res)
end

# @notice Given an input asset amount and  token addresses, calculates all
# subsequent maximum output token amounts.
# @param tokenIn : address of the input token
# @param tokenOut : address of the output token
# @param amountIn : the amount of the input token
# @return The maximum output token amounts.
@view
func getAmountOut{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenIn : felt, tokenOut : felt, amountIn : Uint256) -> (amountOut : Uint256):
    alloc_locals

    let (pool) = getPoolAddress(tokenIn, tokenOut)

    onlyWhitelistedPool(pool)

    let (reserveOut : Uint256) = getPoolReserve(pool, tokenOut)
    let (reserveIn : Uint256) = getPoolReserve(pool, tokenIn)

    let (enoughReserveIn) = uint256_lt(Uint256(0, 0), reserveIn)
    let (enoughReserveOut) = uint256_lt(Uint256(0, 0), reserveOut)

    assert (enoughReserveIn) = 1
    assert (enoughReserveOut) = 1

    let (amountInWithFee, isOverflow_a) = uint256_mul(amountIn, Uint256(997, 0))
    assert (isOverflow_a) = Uint256(0, 0)

    let (reserveInMul1000, isOverflow_b) = uint256_mul(reserveIn, Uint256(1000, 0))
    assert (isOverflow_b) = Uint256(0, 0)

    let (numerator, isOverflow_c) = uint256_mul(amountInWithFee, reserveOut)
    assert (isOverflow_b) = Uint256(0, 0)

    let (denominator, isOverflow_d) = uint256_add(reserveInMul1000, amountInWithFee)
    assert isOverflow_d = 0

    let (amountOut, _) = uint256_unsigned_div_rem(numerator, denominator)

    return (amountOut)
end

func _swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountIn : Uint256, amountOut : Uint256, tokenIn : felt, tokenOut : felt, to : felt,
        pool : felt) -> ():
    alloc_locals

    let (local token0) = IPool.getToken0(pool)

    local amount1Out : Uint256
    local amount0Out : Uint256

    if token0 == tokenOut:
        assert amount0Out = amountOut
        assert amount1Out = Uint256(0, 0)
    else:
        assert amount0Out = Uint256(0, 0)
        assert amount1Out = amountOut
    end

    # swap
    IPool.swap(pool, amount0Out, amount1Out, to, pool)

    swapped.emit(to, tokenIn, tokenOut, amountIn, amountOut, pool)
    return ()
end

# @notice Swaps an exact amount of input tokens for as many output tokens as possible
# @param tokenIn : address of the input token
# @param tokenOut : address of the output token
# @param amountIn : the amount of the input token
# @param amountOutMin : The minimum amount of output tokens that must be received for t
# he transaction not to revert.
@external
func exactInput{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenIn : felt, tokenOut : felt, amountIn : Uint256, amountOutMin : Uint256) -> ():
    alloc_locals

    let (pool) = getPoolAddress(tokenIn, tokenOut)

    onlyWhitelistedPool(pool)

    # get amount out
    let (local amountOut : Uint256) = getAmountOut(tokenIn, tokenOut, amountIn)

    let (enoughAmountOut) = uint256_le(amountOutMin, amountOut)
    assert (enoughAmountOut) = 1

    let (local caller) = get_caller_address()
    IERC20.transferFrom(tokenIn, caller, pool, amountIn)

    _swap(amountIn, amountOut, tokenIn, tokenOut, caller, pool)

    return ()
end

# @notice Receive an exact amount of output tokens for as few input tokens as possible
# @param tokenIn : address of the input token
# @param tokenOut : address of the output token
# @param amountOut : The amount of output tokens to receive.
# @param amountIn_max : The maximum amount of input tokens that can be required before
# the transaction reverts.

@external
func exactOutput{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenIn : felt, tokenOut : felt, amountOut : Uint256, amountIn_max : Uint256) -> ():
    alloc_locals

    let (pool) = getPoolAddress(tokenIn, tokenOut)

    onlyWhitelistedPool(pool)

    let (local amountIn : Uint256) = getAmountIn(tokenIn, tokenOut, amountOut)

    let (enough_amountIn) = uint256_le(amountIn, amountIn_max)
    assert (enough_amountIn) = 1

    let (local caller) = get_caller_address()
    IERC20.transferFrom(tokenIn, caller, pool, amountIn)

    _swap(amountIn, amountOut, tokenIn, tokenOut, caller, pool)

    return ()
end
