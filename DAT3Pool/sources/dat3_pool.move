module dat3::dat3_pool {
    use std::signer;

    use aptos_std::simple_map::SimpleMap;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use dat3::dat3_coin::DAT3;
    friend dat3::dat3_pool_routel;
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
    public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires Pool {
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

    //Is it safe? yes!
    public(friend) fun withdraw<CoinType>(to: address, amount: u64) acquires Pool {
        let a_pool = borrow_global_mut<Pool<CoinType>>(@dat3);
        coin::deposit<CoinType>(to, coin::extract(&mut a_pool.coins, amount));
    }

    // no &signer is right
    public(friend) fun withdraw_reward(to: address, amount: u64) acquires RewardPool {
        let r_pool = borrow_global_mut<RewardPool>(@dat3);
        coin::deposit<DAT3>(to, coin::extract(&mut r_pool.coins, amount));
    }


    // Distribution              Reward/block($DAT3) Reward/day($DAT3)
    // Talk Emission             0.7                 ~5040
    // Active Emission           0.1                 ~720
    // Stake Emission            0.1                 ~720
    // Team&Invester Emission    0.1                 ~720
    // Current Total Emission    1                   ~7200
    //?? What's this?
    public entry fun r_distribution(account: &signer) acquires RewardPool {
        let addr = signer::address_of(account);
        assert!(addr == @dat3, ERR_NOT_ENOUGH_PERMISSIONS);
        let _r_pool = borrow_global_mut<RewardPool>(@dat3);
        // coin::merge(&mut r_pool.coins, coin);
    }


    #[test_only]
    use aptos_framework::aptos_account::create_account;
    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_framework::coin::{is_account_registered, BurnCapability, FreezeCapability, MintCapability};
    #[test_only]
    use std::string;

    #[test_only]
    struct HodeCap has key {
        burnCap: BurnCapability<DAT4>,
        freezeCap: FreezeCapability<DAT4>,
        mintCap: MintCapability<DAT4>,
    }

    #[test_only]
    struct DAT4 has key {}

    #[test(dat3 = @dat3)]
    fun dat3_coin_init(
        dat3: &signer
    ) acquires Pool {
        let addr = signer::address_of(dat3);
        create_account(addr);
        //init dat3_coin
        dat3::dat3_coin::init(dat3);
        coin::register<DAT3>(dat3);
        //initialize dat4
        let (burnCap, freezeCap, mintCap) = coin::initialize<DAT4>(dat3,
            string::utf8(b"DAT3 Coin"),
            string::utf8(b"DAT3"),
            6u8, true);
        //mint dat4_coin
        let dat4_coin = coin::mint(122222222222222, &mintCap);
        //register&deposit coin
        coin::register<DAT4>(dat3);
        coin::deposit(addr, dat4_coin);
        debug::print(&is_account_registered<DAT3>(addr));
        let balance = coin::balance<DAT3>(addr);
        debug::print(&balance);
        debug::print(&coin::balance<DAT3>(addr));
        //init pool
        init_pool<DAT3>(dat3);

        //deposit in pool dat3
        dat3::dat3_pool::deposit<dat3::dat3_coin::DAT3>(dat3, 10000);
        //get dat4 balance in pool
        let r_pool = borrow_global<Pool<DAT3>>(@dat3);
        let coins = &r_pool.coins;
        debug::print(&coin::value(coins));

        //deposit in pool dat4
        move_to(dat3, Pool {
            coins: coin::zero<DAT4>(),
            init_state_events: account::new_event_handle<CreateStateEvent>(dat3),
            deposit_state_events: account::new_event_handle<DepositStateEvent>(dat3),
            withdraw_state_events: account::new_event_handle<WithdrawStateEvent>(dat3),
        });
        dat3::dat3_pool::deposit<DAT4>(dat3, 10001);
        //get dat4 balance in pool
        let r_pool = borrow_global<Pool<DAT4>>(@dat3);
        let coins = &r_pool.coins;
        debug::print(&coin::value(coins));
        //HodeCap
        move_to(dat3, HodeCap { burnCap, freezeCap, mintCap });

        //
        dat3::dat3_pool::withdraw<DAT4>(addr, 1000)
    }
}