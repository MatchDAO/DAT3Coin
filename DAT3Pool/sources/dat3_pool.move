module dat3::dat3_pool {
    use std::signer;

    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};

    use dat3::dat3_coin::DAT3;

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

    struct RewardPool  has key {
        coins: Coin<DAT3>,
    }

    struct CreateStateEvent has drop, store { value: u64 }

    struct DepositStateEvent has drop, store { value: u64 }

    struct WithdrawStateEvent has drop, store { value: u64 }

    struct Inviter<phantom CoinType> has key, store {
        l: SimpleMap<u64, Coin<CoinType>>
    }

    public entry fun init_pool<CoinType>(account: &signer) {
        let addr = signer::address_of(account);
        assert!(addr == @dat3, ERR_NOT_ENOUGH_PERMISSIONS);
        assert!(!exists<Pool<CoinType>>(@dat3), ERR_NOT_ENOUGH_PERMISSIONS);
        assert!(!exists<RewardPool>(@dat3), ERR_NOT_ENOUGH_PERMISSIONS);
        if (coin::is_account_registered<DAT3>(addr)) {
            coin::register<DAT3>(account)
        };
        move_to(account, Pool {
            coins: coin::zero<CoinType>(),
            init_state_events: account::new_event_handle<CreateStateEvent>(account),
            deposit_state_events: account::new_event_handle<DepositStateEvent>(account),
            withdraw_state_events: account::new_event_handle<WithdrawStateEvent>(account),
        });
        move_to(account, RewardPool {
            coins: coin::zero<DAT3>(),
        });
    }

    // deposit token
    public entry fun deposit<CoinType: drop>(account: &signer, amount: u64) acquires Pool {
        let your_coin = coin::withdraw<CoinType>(account, amount);
        let coin_value = coin::value(&your_coin);
        let a_pool = borrow_global_mut<Pool<CoinType>>(@dat3);
        coin::merge(&mut a_pool.coins, your_coin);
        event::emit_event(&mut a_pool.deposit_state_events, DepositStateEvent {
            value: coin_value
        });
    }
    public entry fun deposit_reward(account: &signer, amount: u64) acquires RewardPool {
        let your_coin = coin::withdraw<DAT3>(account, amount);
        let r_pool = borrow_global_mut<RewardPool>(@dat3);
        coin::merge(&mut r_pool.coins, your_coin);

    }
    //Is it safe?
    public entry fun withdraw<CoinType: drop>( account: &signer, to: address,  amount: u64  ) acquires Pool {
        let addr = signer::address_of(account);
        assert!(addr == @dat3, ERR_NOT_ENOUGH_PERMISSIONS);
        let a_pool = borrow_global_mut<Pool<CoinType>>(addr);
        coin::deposit<CoinType>(to, coin::extract(&mut a_pool.coins, amount));
    }

    public entry fun withdraw_reward(account: &signer, to: address, amount: u64) acquires RewardPool {
        let addr = signer::address_of(account);
        assert!(addr == @dat3, ERR_NOT_ENOUGH_PERMISSIONS);
        let r_pool = borrow_global_mut<RewardPool>(addr);
        coin::deposit<DAT3>(to, coin::extract(&mut r_pool.coins, amount));
    }



    // Distribution              Reward/block($DAT3) Reward/day($DAT3)
    // Talk Emission             0.7                 ~5040
    // Active Emission           0.1                 ~720
    // Stake Emission            0.1                 ~720
    // Team&Invester Emission    0.1                 ~720
    // Current Total Emission    1                   ~7200
    public entry fun r_distribution(coin: Coin<DAT3>) acquires RewardPool {
        let r_pool = borrow_global_mut<RewardPool>(@dat3);
        coin::merge(&mut r_pool.coins, coin);
    }
}