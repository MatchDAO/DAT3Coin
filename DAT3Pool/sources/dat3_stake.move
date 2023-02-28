module dat3::dat3_stake {
    use std::signer;
    use std::string;

    use aptos_framework::account;
    use aptos_framework::coin::{Coin, Self};
    use aptos_framework::timestamp;

    use vedat3::vedat3_coin::VEDAT3;

    use dat3::dat3_coin::DAT3;
    use dat3::dat3_coin_boot;
    use dat3::simple_mapv1::{Self, SimpleMapV1};

    struct UserPosition has key, store {
        amount_staked: u64,
        start_time: u64,
        duration: u64,
        reward: Coin<DAT3>,
    }

    struct PoolInfo has key, store {
        data: SimpleMapV1<address, UserPosition>
    }

    struct Pool has key, store {
        stake: Coin<DAT3>,
        reward: Coin<DAT3>,
        rate_of: u128,
        rate_of_decimal: u128,
        max_lock_time: u64,
        burn: coin::BurnCapability<VEDAT3>,
        mint: coin::MintCapability<VEDAT3>,
    }

    const PERMISSION_DENIED: u64 = 1000;
    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NO_TO_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;
    const OUT_OF_RANGE: u64 = 112;
    const INVALID_ARGUMENT: u64 = 113;
    const INCENTIVE_POOL_NOT_FOUND: u64 = 134;
    const DEADLINE_ERR: u64 = 135;

    //7d of seconds
    const ONE_W: u64 = 604800;

    public entry fun init(
        sender: &signer
    )
    {
        let addr = signer::address_of(sender);
        assert!(addr == @dat3, PERMISSION_DENIED);
        assert!(!exists<Pool>(@dat3), ALREADY_EXISTS);
        let module_authority = dat3_coin_boot::retrieveResourceSignerCap(sender);
        let auth_signer = account::create_signer_with_capability(&module_authority);
        let (burn, freeze, mint) = coin::initialize<VEDAT3>(&auth_signer,
            string::utf8(b"veDAT3 Coin"),
            string::utf8(b"veDAT3"),
            6u8, true);
        coin::destroy_freeze_cap(freeze);
        move_to<Pool>(sender, Pool {
            rate_of: 3836,
            rate_of_decimal: 10000,
            max_lock_time: 52,
            stake: coin::zero<DAT3>(), reward: coin::zero<DAT3>(), burn, mint,
        });
        let s = simple_mapv1::create();
        simple_mapv1::add(&mut s, @dat3_admin, UserPosition {
            amount_staked: 0,
            start_time: 0,
            duration: 0,
            reward: coin::zero<DAT3>(),
        });
        move_to<PoolInfo>(sender, PoolInfo {
            data: simple_mapv1::create(),
        });
    }

    public entry fun more_stake(sender: &signer, amount: u64) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), INVALID_ARGUMENT);
        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        // check user
        assert!(simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);
        let pool = borrow_global_mut<Pool>(@dat3);
        // Deposit staked coin
        let stake = coin::withdraw<DAT3>(sender, amount);
        coin::merge(&mut pool.stake, stake);
        //add user staked
        let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);
        user.amount_staked = user.amount_staked + amount;
        if (!coin::is_account_registered<VEDAT3>(addr)) {
            coin::register<VEDAT3>(sender);
        }
    }

    public entry fun more_duration(sender: &signer, duration: u64) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), INVALID_ARGUMENT);
        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        // check user
        assert!(simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);

        //get max_lock_time
        let pool = borrow_global<Pool>(@dat3);
        //add user duration
        let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);
        if ((user.amount_staked + duration) >= pool.max_lock_time) {
            duration = pool.max_lock_time;
        }else {
            duration = user.amount_staked + duration;
        };
        user.duration = duration;
        if (!coin::is_account_registered<VEDAT3>(addr)) {
            coin::register<VEDAT3>(sender);
        }
    }

    /// Deposit stake coin to the incentive pool to start earning rewards.
    /// All pending rewards will be transferred to `sender`.
    public entry fun deposit(sender: &signer, amount: u64, duration: u64) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);

        assert!(coin::is_account_registered<DAT3>(addr), INVALID_ARGUMENT);
        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool = borrow_global_mut<Pool>(@dat3);
        assert!(duration <= pool.max_lock_time, INVALID_ARGUMENT);
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        let now = timestamp::now_seconds();
        let stake = coin::withdraw<DAT3>(sender, amount);
        // Deposit staked coin
        coin::merge(&mut pool.stake, stake);
        // Update UserPosition
        if (!simple_mapv1::contains_key(&pool_info.data, &addr)) {
            simple_mapv1::add(&mut pool_info.data, addr, UserPosition {
                amount_staked: amount,
                start_time: now,
                duration,
                reward: coin::zero<DAT3>(),
            })
        } else {
            let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);
            user.amount_staked = user.amount_staked + amount;
            if (user.duration + duration > 5) {
                duration = 5;
            }else {
                duration = user.duration + duration;
            };
            user.duration = duration;
        };
        if (!coin::is_account_registered<VEDAT3>(addr)) {
            coin::register<VEDAT3>(sender);
        }
    }

    /// Withdraw stake coin from the incentive pool.
    /// All pending rewards will be transferred to `sender`.
    public entry fun withdraw(sender: &signer, amount: u64) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);
        assert!(amount > 0, INVALID_ARGUMENT);
        assert!(coin::is_account_registered<DAT3>(addr), INVALID_ARGUMENT);
        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool = borrow_global_mut<Pool>(@dat3);
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        assert!(!simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);
        let now = timestamp::now_seconds();
        let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);
        assert!(user.amount_staked >= amount, EINSUFFICIENT_BALANCE);
        if (user.duration == 0) {
            user.amount_staked = user.amount_staked - amount;
            coin::deposit(addr, coin::extract(&mut pool.stake, amount))
        }else {
            assert!(now - (user.duration * ONE_W) >= 0, DEADLINE_ERR);
            user.amount_staked = user.amount_staked - amount;
            coin::deposit(addr, coin::extract(&mut pool.stake, amount))
        };
    }

    /// Claim staking rewards without modifying staking position
    public entry fun claim(sender: &signer) acquires PoolInfo {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), INVALID_ARGUMENT);
        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        assert!(!simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);
        let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);

        coin::deposit<DAT3>(addr, coin::extract_all(&mut user.reward));
    }

    /// Claim staking rewards without modifying staking position
    public fun stake_info(sender: &signer): (u64, u64, u64, u64) acquires PoolInfo {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), INVALID_ARGUMENT);
        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool_info = borrow_global<PoolInfo>(@dat3);
        assert!(!simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);
        let user = simple_mapv1::borrow(&pool_info.data, &addr);
        (user.amount_staked,
            user.start_time,
            user.duration,
            coin::value<DAT3>(&user.reward))
    }

    public fun pool_info(): (u64, u64, u128, u128 u64) acquires Pool {

        assert!(exists<Pool>(@dat3), INCENTIVE_POOL_NOT_FOUND);
        let pool = borrow_global<Pool>(@dat3);

        (coin::value<DAT3>(&pool.stake),
            coin::value<DAT3>(&pool.reward),
            pool.rate_of,
            pool.rate_of_decimal,
            pool.max_lock_time)
    }

    public entry fun set_pool(
        sender: &signer, rate_of: u128, rate_of_decimal: u128, max_lock_time: u64
    ) acquires Pool
    {
        let addr = signer::address_of(sender);
        assert!(addr == @dat3, PERMISSION_DENIED);
        assert!(!exists<Pool>(@dat3), ALREADY_EXISTS);
        let pool = borrow_global_mut<Pool>(@dat3);
        if (rate_of > 0) {
            pool.rate_of = rate_of;
        };
        if (rate_of_decimal > 0) {
            pool.rate_of_decimal = rate_of_decimal;
        };
        if (max_lock_time > 0) {
            pool.max_lock_time = max_lock_time;
        };
    }
}