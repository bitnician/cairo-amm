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

@storage_var
func owner() -> (owner_address : felt):
end

@storage_var
func whitlistedPool(poolAddress : felt) -> (res : felt):
end

@storage_var
func poolAddress(token_0 : felt, token_1 : felt) -> (poolAddress : felt):
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
# @param poolAddress the address of the pool contract.
# @dev It throws an error if the given address is not whitelisted.
@view
func verifyPoolIsWhitelisted{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poolAddress : felt) -> ():
    let (res) = whitlistedPool.read(poolAddress)
    assert_not_zero(res)

    return ()
end

# @notice It accepts the token0 and token1 addresses as arguments and returns the pool contract address.
# @param token0 : the token0 address
# @param token1 : the token1 address
# @returns the pool contract address
# @dev It return 0 if the pool contract address is not found.
@view
func getPoolAddress{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a_address : felt, token_b_address : felt) -> (address : felt):
    let (address : felt) = poolAddress.read(token_a_address, token_b_address)

    return (address)
end

# @notice Given some asset amount and reserves, returns an amount of the other asset representing
# equivalent value.
# @param amount_a : the amount of asset A
# @param reserve_a : the reserve of asset A
# @param reserve_b : the reserve of asset B
# @returns amount_b : the amount of asset B
@view
func quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_a : Uint256, reserve_a : Uint256, reserve_b : Uint256) -> (amount_b : Uint256):
    alloc_locals
    let (amount_a_is_zero) = uint256_eq(amount_a, Uint256(0, 0))
    let (reserve_a_is_zero) = uint256_eq(reserve_a, Uint256(0, 0))
    let (reserve_b_is_zero) = uint256_eq(reserve_b, Uint256(0, 0))

    assert amount_a_is_zero = 0
    assert reserve_a_is_zero = 0
    assert reserve_b_is_zero = 0

    let (amount_a_mul_reserve_b, isOverflow) = uint256_mul(amount_a, reserve_b)

    let (amount_b, _) = uint256_unsigned_div_rem(amount_a_mul_reserve_b, reserve_a)

    return (amount_b)
end

# @notice It whitelists a pool contract address.
# @param poolAddress : the address of the pool contract.
# @dev It throws an error if the given address is already whitelisted OR the caller is not Owner.
@external
func whitelistPool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(address) -> (
        ):
    alloc_locals
    onlyOwner()

    let (token0) = IPool.getToken0(address)
    let (token1) = IPool.getToken1(address)

    assert_not_zero(token0)
    assert_not_zero(token1)

    # pool is not whitelisted yet
    let (res) = whitlistedPool.read(address)
    assert res = 0

    whitlistedPool.write(address, 1)

    poolAddress.write(token0, token1, address)
    poolAddress.write(token1, token0, address)

    return ()
end

# @notice It add the first amounts of liquidity to the pool.
# @param sender : the address that receives lp tokens
# @param token_a_address : the address of the token0
# @param token_b_address : the address of the token1
# @param amount_a : the amount of token0
# @param amount_b : the amount of token1
# @param amountsSqrt : square_root(amount_a_desired * amount_b_desired)
# @dev It throws an error if the caller is not the owner OR the pool is not whitelisted
# OR the amount is not valid OR the pool has already some amounts of liquidity.
@external
func initLiquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, token_a_address : felt, token_b_address : felt, amount_a_desired : Uint256,
        amount_b_desired : Uint256, amountsSqrt : Uint256) -> ():
    alloc_locals
    let (_owner) = onlyOwner()

    let (poolAddress) = getPoolAddress(token_a_address, token_b_address)

    verifyPoolIsWhitelisted(poolAddress)

    let (local token_a_reserve : Uint256) = getPoolReserve(poolAddress, token_a_address)

    let (local token_b_reserve : Uint256) = getPoolReserve(poolAddress, token_b_address)

    # Check to see if the pool balance is zero.
    let (reserve_a_zero) = uint256_eq(token_a_reserve, Uint256(0, 0))
    let (reserve_b_zero) = uint256_eq(token_b_reserve, Uint256(0, 0))

    assert reserve_a_zero = 1
    assert reserve_b_zero = 1

    IERC20.transferFrom(token_a_address, sender, poolAddress, amount_a_desired)
    IERC20.transferFrom(token_b_address, sender, poolAddress, amount_b_desired)

    IPool.mint(poolAddress, _owner, amountsSqrt, poolAddress)
    return ()
end

# @notice It adds liquidity to the pool. can be called by anyone
# @param token_a_address : the address of the token0
# @param token_b_address : the address of the token1
# @param amount_a_desired : The amount of tokenA to add as liquidity if
# the B/A price is <= amountBDesired/amountADesired (A depreciates).
# @param amount_b_desired : The amount of tokenB to add as liquidity if
# the A/B price is <= amountADesired/amountBDesired (B depreciates).
# @param amount_a_min : Bounds the extent to which the B/A price can go up before
# the transaction reverts. Must be <= amountADesired.
# @param amount_b_min : Bounds the extent to which the A/B price can go up before
# the transaction reverts. Must be <= amountBDesired.
@external
func addLiquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a_address : felt, token_b_address : felt, amount_a_desired : Uint256,
        amount_b_desired : Uint256, amount_a_min : Uint256, amount_b_min : Uint256) -> ():
    alloc_locals

    let (local caller) = get_caller_address()

    let (poolAddress) = getPoolAddress(token_a_address, token_b_address)

    verifyPoolIsWhitelisted(poolAddress)

    let (local token_a_reserve : Uint256) = getPoolReserve(poolAddress, token_a_address)
    let (local token_b_reserve : Uint256) = getPoolReserve(poolAddress, token_b_address)

    # Check to see if the pool balance is not zero.
    let (reserve_a_zero) = uint256_eq(token_a_reserve, Uint256(0, 0))
    let (reserve_b_zero) = uint256_eq(token_b_reserve, Uint256(0, 0))

    assert reserve_a_zero = 0
    assert reserve_b_zero = 0

    local amount_a : Uint256
    local amount_b : Uint256

    let (amount_b_optimal : Uint256) = quote(amount_a_desired, token_a_reserve, token_b_reserve)
    let (amount_a_optimal : Uint256) = quote(amount_b_desired, token_b_reserve, token_a_reserve)

    let (validate_b_optimal) = uint256_le(amount_b_optimal, amount_b_desired)

    if validate_b_optimal == 1:
        let (enough_b_optimal) = uint256_le(amount_b_min, amount_b_optimal)
        assert enough_b_optimal = 1

        assert amount_a = amount_a_desired
        assert amount_b = amount_b_optimal

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (validate_a_optimal) = uint256_le(amount_a_optimal, amount_a_desired)
        assert validate_a_optimal = 1

        let (enough_a_optimal) = uint256_le(amount_a_min, amount_a_optimal)
        assert enough_a_optimal = 1

        assert amount_a = amount_a_optimal
        assert amount_b = amount_b_desired

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    IERC20.transferFrom(token_a_address, caller, poolAddress, amount_a)
    IERC20.transferFrom(token_b_address, caller, poolAddress, amount_b)

    IPool.mint(poolAddress, caller, Uint256(0, 0), poolAddress)

    return ()
end

# @notice It removes liquidity from the pool. can be called by anyone
# @param token_a_address : the address of the token0
# @param token_b_address : the address of the token1
# @param liquidity_amount : The amount of liquidity tokens to remove.
# @param amount_a_min : The minimum amount of tokenA that must be received for
# the transaction not to revert.
# @param amount_b_min : The minimum amount of tokenB that must be received for
# the transaction not to revert.
# @param to : Recipient of the underlying assets.
@external
func removeLiquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a_address : felt, token_b_address : felt, liquidity_amount : Uint256,
        amount_a_min : Uint256, amount_b_min : Uint256, to : felt) -> ():
    alloc_locals

    let (local caller) = get_caller_address()

    let (poolAddress) = getPoolAddress(token_a_address, token_b_address)

    verifyPoolIsWhitelisted(poolAddress)

    IPool.transferFrom(poolAddress, caller, poolAddress, liquidity_amount)
    let (amount0 : Uint256, amount1 : Uint256) = IPool.burn(poolAddress, to, poolAddress)

    local amount_a : Uint256
    local amount_b : Uint256

    let (token_0) = IPool.getToken0(poolAddress)

    if token_0 == token_a_address:
        assert amount_a = amount0
        assert amount_b = amount1
    else:
        assert amount_a = amount1
        assert amount_b = amount0
    end

    let (enough_amount_a) = uint256_le(amount_a_min, amount_a)
    let (enough_amount_b) = uint256_le(amount_b_min, amount_b)

    assert enough_amount_a = 1
    assert enough_amount_b = 1

    return ()
end

# @notice Getting the pool reserve of token.
# @param poolAddress : address of the pool contract
# @param token_address : address of the token
# @return The reserve of the other token of pool.
func getPoolReserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poolAddress : felt, token_address : felt) -> (balance : Uint256):
    let (_token0) = IPool.getToken0(poolAddress)

    let (token0_reserve : Uint256, token1_reserve : Uint256) = IPool.getReserves(poolAddress)

    if token_address == _token0:
        return (token0_reserve)
    else:
        return (token1_reserve)
    end
end

# @notice Given an output asset amount and token addresses, calculates all
# preceding minimum input token amounts.
# @param tokenInAddress : address of the input token
# @param tokenOutAddress : address of the output token
# @param amountOut : the amount of the output token
# @return The minimum input token amounts.
@view
func getAmountIn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenInAddress : felt, tokenOutAddress : felt, amountOut : Uint256) -> (amountIn : Uint256):
    alloc_locals

    let (poolAddress) = getPoolAddress(tokenInAddress, tokenOutAddress)

    verifyPoolIsWhitelisted(poolAddress)

    let (reserve_out : Uint256) = getPoolReserve(poolAddress, tokenOutAddress)
    let (reserveIn : Uint256) = getPoolReserve(poolAddress, tokenInAddress)

    let (enoughReserveIn) = uint256_lt(Uint256(0, 0), reserveIn)
    let (enoughReserveOut) = uint256_lt(Uint256(0, 0), reserve_out)

    assert (enoughReserveIn) = 1
    assert (enoughReserveOut) = 1

    let (reserveInMulAmountOut, _) = uint256_mul(reserveIn, amountOut)
    let (numerator, _) = uint256_mul(reserveInMulAmountOut, Uint256(1000, 0))

    let (reserveOutSubAmountOut) = uint256_sub(reserve_out, amountOut)
    let (denominator, _) = uint256_mul(reserveOutSubAmountOut, Uint256(997, 0))

    let (amountIn, _) = uint256_unsigned_div_rem(numerator, denominator)

    let (res, isOverflow) = uint256_add(amountIn, Uint256(1, 0))
    assert (isOverflow) = 0

    return (amountIn=res)
end

# @notice Given an input asset amount and  token addresses, calculates all
# subsequent maximum output token amounts.
# @param tokenInAddress : address of the input token
# @param tokenOutAddress : address of the output token
# @param amountIn : the amount of the input token
# @return The maximum output token amounts.
@view
func getAmountOut{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenInAddress : felt, tokenOutAddress : felt, amountIn : Uint256) -> (amountOut : Uint256):
    alloc_locals

    let (poolAddress) = getPoolAddress(tokenInAddress, tokenOutAddress)

    verifyPoolIsWhitelisted(poolAddress)

    let (reserve_out : Uint256) = getPoolReserve(poolAddress, tokenOutAddress)
    let (reserveIn : Uint256) = getPoolReserve(poolAddress, tokenInAddress)

    let (enoughReserveIn) = uint256_lt(Uint256(0, 0), reserveIn)
    let (enoughReserveOut) = uint256_lt(Uint256(0, 0), reserve_out)

    assert (enoughReserveIn) = 1
    assert (enoughReserveOut) = 1

    let (amountInWithFee, _) = uint256_mul(amountIn, Uint256(997, 0))
    let (reserveInMul1000, _) = uint256_mul(reserveIn, Uint256(1000, 0))

    let (numerator, _) = uint256_mul(amountInWithFee, reserve_out)

    let (denominator, _) = uint256_add(reserveInMul1000, amountInWithFee)

    let (amountOut, _) = uint256_unsigned_div_rem(numerator, denominator)

    return (amountOut=amountOut)
end

func _swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amountIn : Uint256, amountOut : Uint256, tokenInAddress : felt, tokenOutAddress : felt,
        to : felt, poolAddress : felt) -> ():
    alloc_locals

    let (local token0) = IPool.getToken0(poolAddress)
    local tokenOut
    local amount1Out : Uint256
    local amount0Out : Uint256

    if token0 == tokenOutAddress:
        assert amount0Out = amountOut
        assert amount1Out = Uint256(0, 0)
    else:
        assert amount0Out = Uint256(0, 0)
        assert amount1Out = amountOut
    end

    # swap
    IPool.swap(poolAddress, amount0Out, amount1Out, to, poolAddress)
    return ()
end

# @notice Swaps an exact amount of input tokens for as many output tokens as possible
# @param tokenInAddress : address of the input token
# @param tokenOutAddress : address of the output token
# @param amountIn : the amount of the input token
# @param amountOutMin : The minimum amount of output tokens that must be received for t
# he transaction not to revert.
@external
func exactInput{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenInAddress : felt, tokenOutAddress : felt, amountIn : Uint256,
        amountOutMin : Uint256) -> ():
    alloc_locals

    let (poolAddress) = getPoolAddress(tokenInAddress, tokenOutAddress)

    verifyPoolIsWhitelisted(poolAddress)

    # get amount out
    let (local amountOut : Uint256) = getAmountOut(tokenInAddress, tokenOutAddress, amountIn)

    let (enoughAmountOut) = uint256_le(amountOutMin, amountOut)
    assert (enoughAmountOut) = 1

    let (local caller) = get_caller_address()
    IERC20.transferFrom(tokenInAddress, caller, poolAddress, amountIn)

    _swap(amountIn, amountOut, tokenInAddress, tokenOutAddress, caller, poolAddress)

    return ()
end

# @notice Receive an exact amount of output tokens for as few input tokens as possible
# @param tokenInAddress : address of the input token
# @param tokenOutAddress : address of the output token
# @param amountOut : The amount of output tokens to receive.
# @param amountIn_max : The maximum amount of input tokens that can be required before
# the transaction reverts.

@external
func exactOutput{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenInAddress : felt, tokenOutAddress : felt, amountOut : Uint256,
        amountIn_max : Uint256) -> ():
    alloc_locals

    let (poolAddress) = getPoolAddress(tokenInAddress, tokenOutAddress)

    verifyPoolIsWhitelisted(poolAddress)

    let (local amountIn : Uint256) = getAmountIn(tokenInAddress, tokenOutAddress, amountOut)

    let (enough_amountIn) = uint256_le(amountIn, amountIn_max)
    assert (enough_amountIn) = 1

    let (local caller) = get_caller_address()
    IERC20.transferFrom(tokenInAddress, caller, poolAddress, amountIn)

    _swap(amountIn, amountOut, tokenInAddress, tokenOutAddress, caller, poolAddress)

    return ()
end
