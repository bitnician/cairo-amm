%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20:
    func balance_of(account : felt) -> (res : Uint256):
    end
    func transfer(recipient : felt, amount : Uint256):
    end

    func transfer_from(sender : felt, recipient : felt, amount : Uint256):
    end
end

@contract_interface
namespace IPool:
    func get_token0() -> (res : felt):
    end

    func get_token1() -> (res : felt):
    end

    func mint(to : felt, amounts_sqrt : Uint256, pool_contract_address : felt):
    end

    func burn(to : felt, pool_contract_address : felt) -> (amount_0 : Uint256, amount_1 : Uint256):
    end

    func transfer_from(sender : felt, recipient : felt, amount : Uint256):
    end

    func is_initialized() -> (res : felt):
    end

    func create_pool(token_a_address : felt, token_b_address : felt):
    end

    func pool_is_created(token_a_address : felt, token_b_address : felt) -> (is_created : felt):
    end

    func swap(
            amount0_out : Uint256, amount1_out : Uint256, to : felt,
            pool_contract_address : felt) -> ():
    end

    func get_pool_id(token_a_address : felt, token_b_address : felt) -> (pool_id : felt):
    end

    func get_reserves() -> (reserve0 : Uint256, reserve1 : Uint256):
    end
end

@contract_interface
namespace IRouter:
    func verify_pool_is_whitelisted(pool_contract_address : felt):
    end

    func get_pool_id(token_a_address : felt, token_b_address : felt) -> (
            pool_contract_address : felt):
    end

    func whitelist_pool(pool_contract_address) -> ():
    end

    func init_liquidity(
            sender : felt, token_a_address : felt, token_b_address : felt,
            amount_a_desired : Uint256, amount_b_desired : Uint256, amounts_sqrt : Uint256) -> ():
    end

    func add_liquidity(
            token_a_address : felt, token_b_address : felt, amount_a_desired : Uint256,
            amount_b_desired : Uint256, amount_a_min : Uint256, amount_b_min : Uint256) -> ():
    end

    func remove_liquidity(
            token_a_address : felt, token_b_address : felt, liquidity_amount : Uint256,
            amount_a_min : Uint256, amount_b_min : Uint256, to : felt) -> ():
    end

    func get_amount_in(token_in_address : felt, token_out_address : felt, amount_out : Uint256) -> (
            amount_in : Uint256):
    end

    func get_amount_out(token_in_address : felt, token_out_address : felt, amount_in : Uint256) -> (
            amount_out : Uint256):
    end

    func exact_input(
            token_in_address : felt, token_out_address : felt, amount_in : Uint256,
            amount_out_min : Uint256) -> ():
    end

    func exact_output(
            token_in_address : felt, token_out_address : felt, amount_out : Uint256,
            amount_in_max : Uint256) -> ():
    end
end
