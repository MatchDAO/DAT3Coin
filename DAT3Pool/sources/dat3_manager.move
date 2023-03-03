module dat3::dat3_manager {
    use std::signer;
    use std::string::{Self, String};

    use aptos_framework::account;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability, Coin};
    use aptos_framework::event;
    use aptos_framework::timestamp::{Self, now_seconds};

    use dat3::dat3_coin::DAT3;

    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_std::math64;
    #[test_only]
    use aptos_framework::aptos_account::create_account;
    #[test_only]
    use aptos_framework::coin::is_account_registered;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use dat3::dat3_pool;
    use aptos_std::math128;
    use std::error;

    struct HodeCap has key {
        burnCap: BurnCapability<DAT3>,
        freezeCap: FreezeCapability<DAT3>,
        mintCap: MintCapability<DAT3>,
    }

    /// genesis info
    struct GenesisInfo has key, store {
        /// seconds
        genesis_time: u64,
        /// withdraw bank event
        withdraw_event: event::EventHandle<WithdrawBankEvent>
    }

    struct MintTime has key, store {
        /// seconds
        time: u64,
        supplyAmount: u64,
    }

    struct WithdrawBankEvent has drop, store {
        /// to address
        to: address,
        /// withdraw amount
        amount: u64,
        /// coin type
        bank_name: String,
    }

    /// 100 million
    const MAX_SUPPLY_AMOUNT: u64 = 5256000 ;
    //365
    const SECONDS_OF_YEAR: u128 = 31536000 ;

    const TOTAL_EMISSION: u128 = 7200;
    //0.7
    const TALK_EMISSION: u128 = 5040;
    //0.1
    const ACTIVE_EMISSION: u128 = 720;
    //0.1
    const STAKE_EMISSION: u128 = 720;
    //0.1
    const INVESTER_EMISSION: u128 = 720;

    const PERMISSION_DENIED: u64 = 1000;
    const SUPPLY_OUT_OF_RANGE: u64 = 1001;

    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NO_TO_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;
    const OUT_OF_RANGE: u64 = 112;
    const INVALID_ARGUMENT: u64 = 113;
    const ASSERT_MINT_ERR: u64 = 114;

    /// bank for  investor
    struct InvestorsBank has key, store { value: Coin<DAT3> }


    public entry fun init_dat3_coin(owner: &signer) acquires HodeCap, MintTime, GenesisInfo {
        assert!(signer::address_of(owner) == @dat3, error::permission_denied(PERMISSION_DENIED));
        //only once
        assert!(!exists<GenesisInfo>(@dat3), error::already_exists(ALREADY_EXISTS));
        let (burnCap, freezeCap, mintCap) =
            coin::initialize<DAT3>(owner,
                string::utf8(b"DAT3 Coin"),
                string::utf8(b"DAT3"),
                6u8, true);
        move_to(owner, HodeCap { burnCap, freezeCap, mintCap });
        coin::register<DAT3>(owner);
        move_to(owner,
            MintTime {
                time: 0,
                supplyAmount: 0
            }
        );

        move_to(owner,
            GenesisInfo {
                genesis_time: now_seconds(),
                withdraw_event: account::new_event_handle<WithdrawBankEvent>(owner)
            }
        );
        mint_to(owner, signer::address_of(owner));
    }


    //Make sure it's only once a day
    fun assert_mint_time(): bool acquires MintTime {
        let last = borrow_global_mut<MintTime>(@dat3);
        assert!(last.supplyAmount <= MAX_SUPPLY_AMOUNT, error::out_of_range(SUPPLY_OUT_OF_RANGE));
        if (last.time == 0) {
            //Genesis
            last.time = 1;
            return true
        }else if (last.time == 1) {
            //the first time
            last.time = now_seconds();
            return true
        }else if (now_seconds() - last.time >= 86399) {
            //timer to mint
            last.time = now_seconds();
            return true
        };
        return false
    }

    fun assert_mint_num(): u128 acquires MintTime, GenesisInfo {
        let last = borrow_global<MintTime>(@dat3);
        let gen = borrow_global<GenesisInfo>(@dat3);
        assert!(last.supplyAmount <= MAX_SUPPLY_AMOUNT, error::out_of_range(SUPPLY_OUT_OF_RANGE));
        let now = timestamp::now_seconds();
        let year = ((now - gen.genesis_time) as u128) / SECONDS_OF_YEAR ;
        let m = 1u128;
        let i = 0u128;
        while (i < year) {
            m = m * 2;
            i = i + 1;
        };
        let mint = TOTAL_EMISSION / m  ;
        return mint
    }

    public entry fun mint_to(owner: &signer, to: address) acquires HodeCap, MintTime, GenesisInfo {
        assert!(signer::address_of(owner) == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(assert_mint_time(), ASSERT_MINT_ERR);
        let cap = borrow_global<HodeCap>(@dat3);

        let ds = math128::pow(10, ((coin::decimals<DAT3>()) as u128));
        let mint_num = assert_mint_num();
        assert!(mint_num > 0, error::aborted(ASSERT_MINT_ERR));
        let mint_amount = ds * mint_num;
        let mint_coins = coin::mint((mint_amount as u64), &cap.mintCap);
        dat3::dat3_pool::deposit_reward_coin(
            owner,
            coin::extract(&mut mint_coins, ((mint_amount * TALK_EMISSION / TOTAL_EMISSION) as u64))
        );
        dat3::dat3_pool::deposit_reward_coin(
            owner,
            coin::extract(&mut mint_coins, ((mint_amount * ACTIVE_EMISSION / TOTAL_EMISSION) as u64))
        );
        dat3::dat3_stake::mint_pool(
            owner,
            coin::extract(&mut mint_coins, ((mint_amount * STAKE_EMISSION / TOTAL_EMISSION) as u64))
        );
        coin::deposit(to, mint_coins);
        let last = borrow_global_mut<MintTime>(@dat3);
        last.supplyAmount = (mint_amount as u64) + last.supplyAmount;
    }


    #[test(dat3 = @dat3, to = @dat3_admin, fw = @aptos_framework)]
    fun dat3_coin_init(
        dat3: &signer, to: &signer, fw: &signer
    ) acquires HodeCap, MintTime, GenesisInfo {
        timestamp::set_time_has_started_for_testing(fw);
        let a = 61u128;
        let temp = ((a / 60u128) as u64);
        let temp1 = ((a % 60u128) as u64);
        if (temp1 > 0) {
            temp = temp + 1;
        };
        debug::print(&temp);
        debug::print(&math64::pow(10, 6));
        let addr = signer::address_of(dat3);
        let to_addr = signer::address_of(to);
        create_account(addr);
        create_account(to_addr);
        init_dat3_coin(dat3);
        dat3_pool::init_pool(dat3);
        coin::register<DAT3>(dat3);
        debug::print(&is_account_registered<DAT3>(addr));
        coin::register<DAT3>(to);
        debug::print(&coin::balance<DAT3>(addr));
        coin::transfer<DAT3>(dat3, to_addr, 11);

        debug::print(&coin::balance<DAT3>(addr));
        debug::print(&coin::balance<DAT3>(to_addr));
    }
}