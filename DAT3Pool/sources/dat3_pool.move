module publisher::dat3_pool {
    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use publisher::dat3_coin;
    use std::signer;
    use publisher::dat3_coin::DAT3;
    friend publisher::dat3_coin;
    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 1000;
    const EINSUFFICIENT_BALANCE: u64 = 107;
    const RESOURCE_EXHAUSTED: u64 = 109;


    const NO_USER: u64 = 108;


    struct Pool<phantom CoinType> has key {
        coins: Coin<CoinType>,
        init_state_events: EventHandle<CreateStateEvent>,
        deposit_state_events: EventHandle<DepositStateEvent>,
        withdraw_state_events: EventHandle<WithdrawStateEvent>,
    }
    struct RewardPool<phantom CoinType> has key {
        coins: Coin<CoinType>,
    }

    struct CreateStateEvent has drop, store { value: u64 }

    struct DepositStateEvent has drop, store { value: u64 }

    struct WithdrawStateEvent has drop, store { value: u64 }

    struct Inviter<phantom CoinType> has key, store {
        l: SimpleMap<u64, Coin<CoinType>>
    }

    public entry fun init_pool<CoinType>(account: &signer) {
        assert!(signer::address_of(account) == @publisher, ERR_NOT_ENOUGH_PERMISSIONS);
        if (!exists<Pool<CoinType>>(@publisher)) {
            move_to(account, Pool {
                coins: coin::zero<CoinType>(),
                init_state_events: account::new_event_handle<CreateStateEvent>(account),
                deposit_state_events: account::new_event_handle<DepositStateEvent>(account),
                withdraw_state_events: account::new_event_handle<WithdrawStateEvent>(account),
            });
        };
        if (!exists<RewardPool<DAT3>>(@publisher)) {
            move_to(account, RewardPool<> {
                coins: coin::zero<DAT3>(),
            });
        };

    }
    // deposit token
    public entry fun deposit<CoinType: drop>( coin: Coin<CoinType>) acquires Pool {
       let coin_value= coin::value(&coin);
        let a_pool = borrow_global_mut<Pool<CoinType>>(@publisher);
        coin::merge(&mut a_pool.coins, coin);
        event::emit_event(&mut a_pool.deposit_state_events, DepositStateEvent {
            value: coin_value
        });
    }

    public entry fun withdraw<CoinType: drop>(amount: u64): Coin<CoinType> acquires Pool {
        let a_pool = borrow_global_mut<Pool<CoinType>>(@publisher);
        coin::extract(&mut a_pool.coins, amount)
    }
    public entry fun withdraw_reward<CoinType: drop>(amount: u64): Coin<DAT3> acquires  RewardPool {
        let r_pool = borrow_global_mut<RewardPool<DAT3>>(@publisher);
        coin::extract(&mut r_pool.coins, amount)
    }
    public entry fun deposit_reward( coin: Coin<DAT3>) acquires  RewardPool {
        let r_pool = borrow_global_mut<RewardPool<DAT3>>(@publisher);
        coin::merge(&mut r_pool.coins, coin);
    }
    // Distribution              Reward/block($DAT3) Reward/day($DAT3)
    // Talk Emission             0.7                 ~5040
    // Active Emission           0.1                 ~720
    // Stake Emission            0.1                 ~720
    // Team&Invester Emission    0.1                 ~720
    // Current Total Emission    1                   ~7200
    public entry fun r_distribution  ( coin: Coin<DAT3>) acquires  RewardPool {
        let r_pool = borrow_global_mut<RewardPool<DAT3>>(@publisher);
        coin::merge(&mut r_pool.coins, coin);
    }
}