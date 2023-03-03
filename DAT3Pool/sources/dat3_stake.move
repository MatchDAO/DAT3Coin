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
    use std::vector;
    use aptos_std::math128;
    use std::error;

    friend dat3::dat3_manager;
    struct UserPosition has key, store {
        amount_staked: u64,
        start_time: u64,
        duration: u64,
        reward: Coin<DAT3>,
        flexible:bool
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

    struct GenesisInfo has key, store {
        /// seconds
        genesis_time: u64,
    }

    /// 100 million
    const MAX_SUPPLY_AMOUNT: u64 = 5256000 ;
    //365
    const SECONDS_OF_YEAR: u128 = 31536000 ;
    //365
    const SECONDS_OF_WEEK: u128 = 604800 ;
    //ONE DAY
    const SECONDS_OF_DAY: u128 = 86400 ;

    const TOTAL_EMISSION: u128 = 7200;


    const PERMISSION_DENIED: u64 = 1000;
    const INVALID_ARGUMENT: u64 = 105;
    const OUT_OF_RANGE: u64 = 106;
    const EINSUFFICIENT_BALANCE: u64 = 107;
    const NO_USER: u64 = 108;
    const NO_TO_USER: u64 = 109;
    const NOT_FOUND: u64 = 111;
    const ALREADY_EXISTS: u64 = 112;
    const INCENTIVE_POOL_NOT_FOUND: u64 = 400;
    const DEADLINE_ERR: u64 = 401;

    //7d of seconds
    const ONE_W: u64 = 604800;

    public entry fun init(
        sender: &signer
    )
    {
        let addr = signer::address_of(sender);
        assert!(addr == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(!exists<GenesisInfo>(@dat3), error::not_found(NOT_FOUND));

        if (!exists<Pool>(addr)) {
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
        };

        if (!exists<PoolInfo>(addr)) {
            let s = simple_mapv1::create();
            simple_mapv1::add(&mut s, @dat3_admin, UserPosition {
                amount_staked: 0,
                start_time: 0,
                duration: 0,
                reward: coin::zero<DAT3>(),
                flexible:false
            });

            move_to<PoolInfo>(sender, PoolInfo {
                data: s,
            });
        };

        move_to<GenesisInfo>(sender, GenesisInfo { genesis_time: timestamp::now_seconds() })
    }

    public entry fun more_stake(sender: &signer, amount: u64) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), error::aborted(NOT_FOUND));
        assert!(exists<Pool>(@dat3), error::aborted(INCENTIVE_POOL_NOT_FOUND));
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        // check user
        assert!(simple_mapv1::contains_key(&pool_info.data, &addr), error::aborted(NO_USER));
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
        assert!(coin::is_account_registered<DAT3>(addr), error::permission_denied(INVALID_ARGUMENT));
        assert!(exists<Pool>(@dat3), error::aborted(INCENTIVE_POOL_NOT_FOUND));
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

        assert!(coin::is_account_registered<DAT3>(addr), error::aborted(INVALID_ARGUMENT));
        assert!(exists<Pool>(@dat3), error::aborted(INCENTIVE_POOL_NOT_FOUND));
        if (!coin::is_account_registered<VEDAT3>(addr)) {
            coin::register<VEDAT3>(sender);
        };
        let pool = borrow_global_mut<Pool>(@dat3);
        assert!(duration <= pool.max_lock_time, error::aborted(INVALID_ARGUMENT));
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        let now = timestamp::now_seconds();
        let stake = coin::withdraw<DAT3>(sender, amount);
        // Deposit staked coin
        coin::merge(&mut pool.stake, stake);
        let flexible =false;
        if(duration>0){
            flexible=true;
        };
        // Update UserPosition
        if (!simple_mapv1::contains_key(&pool_info.data, &addr)) {
            simple_mapv1::add(&mut pool_info.data, addr, UserPosition {
                amount_staked: amount,
                start_time: now,
                duration,
                reward: coin::zero<DAT3>(),
                flexible,
            })
        } else {
            let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);
            user.amount_staked = user.amount_staked + amount;
            if (user.duration + duration >= pool.max_lock_time) {
                duration = 52;
            }else {
                duration = user.duration + duration;
            };
            if(duration>0){
                flexible=false;
            };
            user.duration = duration;
            user.flexible=flexible;
        };

    }

    /// Withdraw stake coin from the incentive pool.
    /// All pending rewards will be transferred to `sender`.
    public entry fun withdraw(sender: &signer) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), error::aborted(INVALID_ARGUMENT));
        assert!(exists<Pool>(@dat3), error::aborted(INCENTIVE_POOL_NOT_FOUND));
        let pool = borrow_global_mut<Pool>(@dat3);
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        assert!(!simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);
        let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);
        assert!(user.amount_staked > 0, error::aborted(EINSUFFICIENT_BALANCE));
        user.amount_staked = 0;
        user.duration = 0;
        user.start_time = 0;
        coin::deposit(addr, coin::extract(&mut pool.stake, user.amount_staked));
    }

    /// Claim staking rewards without modifying staking position
    public entry fun claim(sender: &signer) acquires PoolInfo {
        let addr = signer::address_of(sender);
        assert!(coin::is_account_registered<DAT3>(addr), error::aborted(INVALID_ARGUMENT));
        assert!(exists<Pool>(@dat3), error::aborted(INCENTIVE_POOL_NOT_FOUND));
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        assert!(!simple_mapv1::contains_key(&pool_info.data, &addr), NO_USER);
        let user = simple_mapv1::borrow_mut(&mut pool_info.data, &addr);

        coin::deposit<DAT3>(addr, coin::extract_all(&mut user.reward));
    }


    #[view]
    public fun pool_info(): (u64, u64, u128, u128, u64) acquires Pool {
        assert!(exists<Pool>(@dat3), error::aborted(INCENTIVE_POOL_NOT_FOUND));
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
        assert!(addr == @dat3, error::aborted(PERMISSION_DENIED));
        assert!(!exists<Pool>(@dat3), error::aborted(ALREADY_EXISTS));
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

    public(friend) fun mint_pool(
        sender: &signer, coins: Coin<DAT3>) acquires Pool, PoolInfo
    {
        let addr = signer::address_of(sender);
        assert!(addr == @dat3, error::permission_denied(PERMISSION_DENIED));
        if (!exists<Pool>(addr)) {
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
        };

        if (!exists<PoolInfo>(addr)) {
            let s = simple_mapv1::create();
            simple_mapv1::add(&mut s, @dat3_admin, UserPosition {
                amount_staked: 0,
                start_time: 0,
                duration: 0,
                reward: coin::zero<DAT3>(),
                flexible:false,
            });

            move_to<PoolInfo>(sender, PoolInfo {
                data: s,
            });
        };
        assert!(exists<Pool>(@dat3), error::not_found(NOT_FOUND));
        let pool = borrow_global_mut<Pool>(@dat3);
        coin::merge(&mut pool.reward, coins);

        let pool_info = borrow_global_mut<PoolInfo>(@dat3);
        let leng = simple_mapv1::length(&mut pool_info.data);
        let volume = 0u128;
        let volume_staked = 0u128;
        let i = 0;
        let users = vector::empty<address>();
        //Expected a single non-reference type
        let now = timestamp::now_seconds();
        while (i < leng) {
            let (address, user) = simple_mapv1::find_index_mut(&mut pool_info.data, i);
            //   this is passed
            let passed = ((((now as u128) - (user.start_time as u128)) / SECONDS_OF_WEEK) as u64)  ;
            // check amount_staked,check duration ，check
            if (user.amount_staked > 0 && user.duration > 0 && user.duration > passed) {
                volume = volume + ((user.amount_staked as u128) * ((((user.duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal));
                volume_staked = volume_staked + (user.amount_staked as u128);
                vector::push_back(&mut users, *address)
            };
            i = i + 1;
        };
        leng = vector::length(&users);
        if (leng > 0) {
            i = 0;
            let reward_val = coin::value<DAT3>(&mut pool.reward)  ;
            while (i < leng) {
                let user_address = vector::borrow_mut(&mut users, i);
                let get = simple_mapv1::borrow_mut(&mut pool_info.data, user_address);
                let passed = ((((now as u128) - (get.start_time as u128)) / SECONDS_OF_WEEK) as u64)  ;

                let award = (((reward_val as u128) * ((get.amount_staked as u128) * ((((get.duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal)) / volume
                ) as u64);
                if (coin::value<DAT3>(&mut pool.reward) > 0) {
                    coin::merge(&mut get.reward, coin::extract(&mut pool.reward, award))
                };
                i = i + 1;
            };
        };
    }

    #[view]
    public fun apr(
        staking: u64, duration: u64
    ): (u64, u64, u64, bool, u64, u64, u64, u64,u64,u64 ) acquires Pool, PoolInfo, GenesisInfo
    {
        assert!(!exists<Pool>(@dat3), error::already_exists(ALREADY_EXISTS));

        let vedat3 = 0u64;
        let staking = staking; //done
        let duration =duration; //done
        let flexible =false; //done
        let apr = 0u64;
        let roi=0u64;
        let boost = 0 ;   //done
        let start = 0u64; //done
        let rewards = 0u64;//done
        let total_staking = 0u64;

        if(duration>0){
            flexible=true;
        };

        let pool = borrow_global<Pool>(@dat3);
        //all staking
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);

        boost=  pool.rate_of_decimal ;
        let leng = simple_mapv1::length(&mut pool_info.data);
        let now = timestamp::now_seconds();
        start=now;
        //temporary container
        let users = vector::empty<address>();

        //index
        let i = 0u64;
        while (i < leng) {
            let (address, user) = simple_mapv1::find_index_mut(&mut pool_info.data, i);
            //   this is passed
            let passed = ((((now as u128) - (user.start_time as u128)) / SECONDS_OF_WEEK) as u64)  ;
            // check amount_staked,check duration ，check
            if (user.amount_staked > 0   && (user.duration > passed ||user.flexible)) {
                //All users who are staking
                total_staking = total_staking + user.amount_staked;
                vector::push_back(&mut users, *address)
            };
            i = i + 1;
        };
        //genesis_time
        let gen = borrow_global<GenesisInfo>(@dat3);
        //simulate_mint time
        let time = (now as u128);
        i = 0;
        let maximum = duration * 7 + 1;
        if(flexible){
            maximum=8;
        };
        let all_simulate_reward = 0u128;
        //Calculate the daily
        while (i < maximum) {
            leng = vector::length(&users);
            let j = 0u64;
            //simulate mint
            let mint = simulate_mint(gen.genesis_time, (time as u64));
            let volume = 0u128;
            let passed = (((time - (now as u128)) / SECONDS_OF_WEEK) as u64);
            //add your stake factor
            let your_stake_factor = (staking as u128) * ((((duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal) ;
            //reset daily stake factor
            volume = your_stake_factor;
            if (leng > 0) {
                while (j < leng) {
                    let add_j = vector::borrow(&users, j);
                    let temp_user = simple_mapv1::borrow(&pool_info.data, add_j);
                    // duration
                    if (duration > passed||temp_user.flexible ) {
                        passed = (((time - (temp_user.start_time as u128)) / SECONDS_OF_WEEK) as u64);
                        if ((temp_user.duration > passed)||temp_user.flexible) {
                            volume = volume + ((temp_user.amount_staked as u128) * ((((temp_user.duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal));
                        }else {
                            vector::swap_remove(&mut users, j)  ;
                            j = j - 1;
                            if ((leng - j) > 1) {
                                leng = leng - 1;
                            };
                        };
                    };
                    j = j + 1;
                };
                all_simulate_reward = all_simulate_reward + mint * your_stake_factor / volume;
            };
            time = time + SECONDS_OF_DAY;
            i = i + 1;
        };
        apr = ((all_simulate_reward * 1000000 / (staking as u128) as u64));
        rewards = (all_simulate_reward as u64);
        // let vedat3 = 0u64;
        // let staking = 0u64; //done
        // let duration = 0u64; //done
        // let flexible =false; //done
        // let apr = 0u64;
        // let roi=0u64;
        // let boost = 0 ;   //done
        // let start = 0u64; //done
        // let rewards = 0u64;//done
        // let current_rewards = 0u64;//done
        (vedat3, staking, duration,flexible,apr,roi,( boost as u64),start,rewards ,total_staking )
    }
    #[view]
    public fun your_staking(
        addr:address
    ): (u64, u64, u64, bool, u64, u64, u64, u64,u64,u64,u64 ) acquires Pool, PoolInfo, GenesisInfo
    {
        assert!(!exists<Pool>(@dat3), error::already_exists(ALREADY_EXISTS));

        let vedat3 = 0u64;
        let staking = 0u64; //done
        let duration = 0u64; //done
        let flexible =false; //done
        let apr = 0u64;
        let roi=0u64;
        let boost = 0 ;   //done
        let start = 0u64; //done
        let rewards = 0u64;//done
        let current_rewards = 0u64;//done

        let total_staking = 0u64;

        let pool = borrow_global<Pool>(@dat3);
        //all staking
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);

        let your_s=simple_mapv1::borrow(&pool_info.data,*addr);
        duration=your_s.duration;
        staking=your_s.amount_staked;
        flexible=your_s.flexible;
        current_rewards=coin::value<DAT3>(&mut your_s.reward);
        start = your_s.start_time;
        boost=  pool.rate_of_decimal ;
        let leng = simple_mapv1::length(&mut pool_info.data);
        let now = timestamp::now_seconds();

        //temporary container
        let users = vector::empty<address>();

        //index
        let i = 0u64;
        while (i < leng) {
            let (address, user) = simple_mapv1::find_index_mut(&mut pool_info.data, i);
            //   this is passed
            let passed = ((((now as u128) - (user.start_time as u128)) / SECONDS_OF_WEEK) as u64)  ;
            // check amount_staked,check duration ，check
            if (user.amount_staked > 0   && (user.duration > passed ||user.flexible)) {
                //All users who are staking
                total_staking = total_staking + user.amount_staked;
                vector::push_back(&mut users, *address)
            };
            i = i + 1;
        };
        //genesis_time
        let gen = borrow_global<GenesisInfo>(@dat3);
        //simulate_mint time
        let time = (now as u128);
        i = 0;
        let maximum = duration * 7 + 1;
        if(flexible){
            maximum=8;
        };
        let all_simulate_reward = 0u128;
        //Calculate the daily
        while (i < maximum) {
            leng = vector::length(&users);
            let j = 0u64;
            //simulate mint
            let mint = simulate_mint(gen.genesis_time, (time as u64));
            let volume = 0u128;
            let passed = (((time - (now as u128)) / SECONDS_OF_WEEK) as u64);
            //add your stake factor
            let your_stake_factor = (staking as u128) * ((((duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal) ;
            //reset daily stake factor
            volume = your_stake_factor;
            if (leng > 0) {
                while (j < leng) {
                    let add_j = vector::borrow(&users, j);
                    let temp_user = simple_mapv1::borrow(&pool_info.data, add_j);
                    // duration
                    if ((duration > passed||temp_user.flexible) && *add_j!=addr ) {
                        passed = (((time - (temp_user.start_time as u128)) / SECONDS_OF_WEEK) as u64);
                        if ((temp_user.duration > passed)||temp_user.flexible) {
                            volume = volume + ((temp_user.amount_staked as u128) * ((((temp_user.duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal));
                        }else {
                            vector::swap_remove(&mut users, j)  ;
                            j = j - 1;
                            if ((leng - j) > 1) {
                                leng = leng - 1;
                            };
                        };
                    };
                    j = j + 1;
                };
                all_simulate_reward = all_simulate_reward + mint * your_stake_factor / volume;
            };
            time = time + SECONDS_OF_DAY;
            i = i + 1;
        };
        apr = ((all_simulate_reward * 1000000 / (staking as u128) as u64));
        rewards = (all_simulate_reward as u64);
        // let vedat3 = 0u64;
        // let staking = 0u64; //done
        // let duration = 0u64; //done
        // let flexible =false; //done
        // let apr = 0u64;
        // let roi=0u64;
        // let boost = 0 ;   //done
        // let start = 0u64; //done
        // let rewards = 0u64;//done
        // let current_rewards = 0u64;//done
        (vedat3, staking, duration,flexible,apr,roi,( boost as u64),start,rewards,current_rewards ,total_staking )
    }

    #[view]
    public fun your_staking_more(
        addr:address,staking_more:u64,duration_more:u64
    ): (u64, u64, u64, bool, u64, u64, u64, u64,u64,u64,u64 ) acquires Pool, PoolInfo, GenesisInfo
    {
        assert!(!exists<Pool>(@dat3), error::already_exists(ALREADY_EXISTS));

        let vedat3 = 0u64;
        let staking = 0u64; //done
        let duration = 0u64; //done
        let flexible =false; //done
        let apr = 0u64;
        let roi=0u64;
        let boost = 0 ;   //done
        let start = 0u64; //done
        let rewards = 0u64;//done
        let current_rewards = 0u64;//done

        let total_staking = 0u64;

        let pool = borrow_global<Pool>(@dat3);
        //all staking
        let pool_info = borrow_global_mut<PoolInfo>(@dat3);

        let your_s=simple_mapv1::borrow(&pool_info.data,*addr);
        duration=your_s.duration+duration_more;
        staking=your_s.amount_staked+staking_more;
        flexible=your_s.flexible;
        current_rewards=coin::value<DAT3>(&mut your_s.reward);
        start = your_s.start_time;
        boost=  pool.rate_of_decimal ;
        let leng = simple_mapv1::length(&mut pool_info.data);
        let now = timestamp::now_seconds();

        //temporary container
        let users = vector::empty<address>();

        //index
        let i = 0u64;
        while (i < leng) {
            let (address, user) = simple_mapv1::find_index_mut(&mut pool_info.data, i);
            //   this is passed
            let passed = ((((now as u128) - (user.start_time as u128)) / SECONDS_OF_WEEK) as u64)  ;
            // check amount_staked,check duration ，check
            if (user.amount_staked > 0   && (user.duration > passed ||user.flexible)) {
                //All users who are staking
                total_staking = total_staking + user.amount_staked;
                vector::push_back(&mut users, *address)
            };
            i = i + 1;
        };
        //genesis_time
        let gen = borrow_global<GenesisInfo>(@dat3);
        //simulate_mint time
        let time = (now as u128);
        i = 0;
        let maximum = duration * 7 + 1;
        if(flexible){
            maximum=8;
        };
        let all_simulate_reward = 0u128;
        //Calculate the daily
        while (i < maximum) {
            leng = vector::length(&users);
            let j = 0u64;
            //simulate mint
            let mint = simulate_mint(gen.genesis_time, (time as u64));
            let volume = 0u128;
            let passed = (((time - (now as u128)) / SECONDS_OF_WEEK) as u64);
            //add your stake factor
            let your_stake_factor = (staking as u128) * ((((duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal) ;
            //reset daily stake factor
            volume = your_stake_factor;
            if (leng > 0) {
                while (j < leng) {
                    let add_j = vector::borrow(&users, j);
                    let temp_user = simple_mapv1::borrow(&pool_info.data, add_j);
                    // duration
                    if ((duration > passed||temp_user.flexible) && *add_j!=addr ) {
                        passed = (((time - (temp_user.start_time as u128)) / SECONDS_OF_WEEK) as u64);
                        if ((temp_user.duration > passed)||temp_user.flexible) {
                            volume = volume + ((temp_user.amount_staked as u128) * ((((temp_user.duration - passed) as u128) * pool.rate_of) + pool.rate_of_decimal));
                        }else {
                            vector::swap_remove(&mut users, j)  ;
                            j = j - 1;
                            if ((leng - j) > 1) {
                                leng = leng - 1;
                            };
                        };
                    };
                    j = j + 1;
                };
                all_simulate_reward = all_simulate_reward + mint * your_stake_factor / volume;
            };
            time = time + SECONDS_OF_DAY;
            i = i + 1;
        };
        apr = ((all_simulate_reward * 1000000 / (staking as u128) as u64));
        rewards = (all_simulate_reward as u64);
        // let vedat3 = 0u64;
        // let staking = 0u64; //done
        // let duration = 0u64; //done
        // let flexible =false; //done
        // let apr = 0u64;
        // let roi=0u64;
        // let boost = 0 ;   //done
        // let start = 0u64; //done
        // let rewards = 0u64;//done
        // let current_rewards = 0u64;//done
        (vedat3, staking, duration,flexible,apr,roi,( boost as u64),start,rewards,current_rewards ,total_staking )
    }

    fun assert_mint_num(): u128 acquires GenesisInfo {
        let gen = borrow_global<GenesisInfo>(@dat3);
        let now = timestamp::now_seconds();
        let year = ((now - gen.genesis_time) as u128) / SECONDS_OF_YEAR ;
        let m = 1u128;
        let i = 0u128;
        while (i < year) {
            m = m * 2;
            i = i + 1;
        };
        let mint = TOTAL_EMISSION / m  ;
        return mint * math128::pow(10, (coin::decimals<DAT3>() as u128))
    }

    fun simulate_mint(genesis_time: u64, now: u64): u128 {
        let year = ((now - genesis_time) as u128) / SECONDS_OF_YEAR ;
        let m = 1u128;
        let i = 0u128;
        while (i < year) {
            m = m * 2;
            i = i + 1;
        };
        let mint = TOTAL_EMISSION / m  ;
        return mint * math128::pow(10, (coin::decimals<DAT3>() as u128))
    }
}