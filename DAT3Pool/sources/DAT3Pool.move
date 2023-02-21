module publisher::DAT3Pool {
    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};

    const EINSUFFICIENT_BALANCE: u64 = 107;
    const RESOURCE_EXHAUSTED: u64 = 109;


    const NO_USER: u64 = 108;


    struct Pool<phantom CoinType> has key {
        value: Coin<CoinType>,
        init_state_events: EventHandle<CreateStateEvent>,
        deposit_state_events: EventHandle<DepositStateEvent>,
        withdraw_state_events: EventHandle<WithdrawStateEvent>,
    }

    struct CreateStateEvent has drop, store { value: u64 }

    struct DepositStateEvent has drop, store { value: u64 }

    struct WithdrawStateEvent has drop, store { value: u64 }

    struct Inviter<phantom CoinType> has key, store {
        l: SimpleMap<u64, Coin<CoinType>>
    }

    public entry fun init_pool<CoinType>(account: &signer) {
        move_to(account, Pool {
            value: coin::zero<CoinType>(),
            init_state_events: account::new_event_handle<CreateStateEvent>(account),
            deposit_state_events: account::new_event_handle<DepositStateEvent>(account),
            withdraw_state_events: account::new_event_handle<WithdrawStateEvent>(account),
        });
    }


    // deposit token
    public entry fun deposit<CoinType: drop>( coin: Coin<CoinType>) acquires Pool {
       let coin_value= coin::value(&coin);
        let a_pool = borrow_global_mut<Pool<CoinType>>(@publisher);
        coin::merge(&mut a_pool.value, coin);
        event::emit_event(&mut a_pool.deposit_state_events, DepositStateEvent {
            value: coin_value
        });
    }

    public entry fun withdraw<CoinType: drop>(amount: u64): Coin<CoinType> acquires Pool {
        let a_pool = borrow_global_mut<Pool<CoinType>>(@publisher);
        coin::extract(&mut a_pool.value, amount)
    }


}