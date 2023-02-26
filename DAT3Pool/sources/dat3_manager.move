module dat3::dat3_manager {
    use std::signer;
    use std::string;
    use aptos_std::math64;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability, Coin};
    use aptos_framework::event;
    use std::string::String;
    use aptos_framework::account;
    use aptos_framework::timestamp::now_seconds;
    use dat3::dat3_coin::DAT3;
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
        supplyAmount:u64,
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

    const TOTAL_EMISSION: u64 = 7200;
    const TALK_EMISSION: u64 = 5040;
    const ACTIVE_EMISSION: u64 = 720;
    const STAKE_EMISSION: u64 = 720;
    const INVESTER_EMISSION: u64 = 720;

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


    public entry fun init_dat3_coin(owner: &signer) acquires HodeCap, MintTime {
        assert!(signer::address_of(owner) == @dat3, PERMISSION_DENIED);
        //only once
        assert!(!exists<GenesisInfo>(@dat3), ALREADY_EXISTS);
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
        mint_to(owner,signer::address_of(owner));
    }


    //Make sure it's only once a day
    fun assert_mint_time(): bool acquires MintTime {
        let last = borrow_global_mut<MintTime>(@dat3);
        assert!(last.supplyAmount<=MAX_SUPPLY_AMOUNT,SUPPLY_OUT_OF_RANGE);
        if ( last.time == 0){//Genesis
            last.time = 1;
            return true
        }else if ( last.time == 1){//the first time
            last.time =  now_seconds();
            return true
        }else if (now_seconds() - last.time >= 86399) { //timer to mint
            last.time = now_seconds();
            return true
        };
        return false
    }

    public entry fun mint_to(owner: &signer, to: address) acquires HodeCap, MintTime {
        assert!(signer::address_of(owner) == @dat3, PERMISSION_DENIED);
        assert!(assert_mint_time(), ASSERT_MINT_ERR);
        let cap = borrow_global<HodeCap>(@dat3);
        let ds = math64::pow(10, ((coin::decimals<DAT3>()) as u64));
        let mint_amount=ds * TOTAL_EMISSION;
        let mint_coins = coin::mint(mint_amount, &cap.mintCap);
        dat3::dat3_pool::deposit_reward_coin(owner,coin::extract(&mut mint_coins, TALK_EMISSION * ds));
        dat3::dat3_pool::deposit_reward_coin(owner,coin::extract(&mut mint_coins, ACTIVE_EMISSION * ds));
        //todo   to STAKE_EMISSION
        coin::deposit(to, mint_coins);
        let last = borrow_global_mut<MintTime>(@dat3);
        last.supplyAmount=mint_amount+last.supplyAmount;
    }





    #[test_only]
    use aptos_framework::coin::is_account_registered;
    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_framework::aptos_account::{create_account};
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use dat3::dat3_pool;


    #[test(dat3 = @dat3, to = @dat3_admin,fw=@aptos_framework)]
    fun dat3_coin_init(
        dat3: &signer, to: &signer,fw:&signer
    ) acquires HodeCap, MintTime {
        timestamp::set_time_has_started_for_testing(fw);
        let a=61u128;
        let temp = ((a /60u128) as u64);
        let temp1 = ((a  %60u128) as u64);
        if(temp1>0){
            temp=temp+1;
        };
        debug::print(&temp);
        debug::print(&math64::pow(10, 6));
        let addr = signer::address_of(dat3);
        let to_addr = signer::address_of(to);
        create_account(addr);
        create_account(to_addr);
        init_dat3_coin(dat3);
        dat3_pool::init_pool<DAT3>(dat3);
        coin::register<DAT3>(dat3);
        debug::print(&is_account_registered<DAT3>(addr));
        coin::register<DAT3>(to);
        debug::print(&coin::balance<DAT3>(addr));
        coin::transfer<DAT3>(dat3, to_addr, 11);

        debug::print(&coin::balance<DAT3>(addr));
        debug::print(&coin::balance<DAT3>(to_addr));
    }
}