/// this module deploy code to be used in main source code
module dat3::dat3_coin_boot {
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};

    use aptos_framework::coin;
    use std::string;
    use aptos_std::math64;
    use aptos_framework::code;
    use vedat3::vedat3_coin::VEDAT3;

    #[test_only]
    use aptos_std::debug;
    use aptos_framework::coin::{BurnCapability, FreezeCapability, MintCapability};


    const ERR_PERMISSIONS: u64 = 403;

    struct CapHode has key {
        burnCap: BurnCapability<VEDAT3>,
        freezeCap: FreezeCapability<VEDAT3>,
        mintCap: MintCapability<VEDAT3>,
    }

    struct BootResourceSignerStore has key {
        sinCap: SignerCapability,
    }

    /// Deploy code & store tempo resource signer
    public entry fun initializeWithResourceAccount(
        admin: &signer,
        metadata: vector<u8>,
        byteCode: vector<u8>,
        seed: vector<u8>
    ) {
        assert!(signer::address_of(admin) == @dat3, ERR_PERMISSIONS);
        let (resourceSigner, sinCap) =
            account::create_resource_account(admin, seed);

        code::publish_package_txn(&resourceSigner, metadata, vector[byteCode]);
        let (burnCap, freezeCap, mintCap) =
            coin::initialize<VEDAT3>(admin,
                string::utf8(b"veDAT3 Coin"),
                string::utf8(b"veDAT3"),
                8u8, true);
        let mint_coin = coin::mint(math64::pow(10, (coin::decimals<VEDAT3>() as u64)) * 7200, &mintCap);
        coin::register<VEDAT3>(admin);
        coin::deposit(signer::address_of(admin), mint_coin);
        move_to(admin, CapHode { burnCap, freezeCap, mintCap, });
        move_to(admin, BootResourceSignerStore { sinCap });
    }

    /// Destroys temporary storage for resource account signer capability and returns signer capability.
    /// It needs for initialization of aptospad.
    public fun retrieveResourceSignerCap(aptospadAdmin: &signer): SignerCapability acquires BootResourceSignerStore {
        assert!(signer::address_of(aptospadAdmin) == @dat3, ERR_PERMISSIONS);
        let BootResourceSignerStore { sinCap } = move_from<BootResourceSignerStore>(
            signer::address_of(aptospadAdmin)
        );
        sinCap
    }

    #[test(dat3 = @dat3)]
    fun test_resource_account(
        dat3: &signer
    ) {
        let (_, signer_cap) =
            account::create_resource_account(dat3, b"dat3");
        let sig = account::create_signer_with_capability(&signer_cap);
        debug::print(&signer::address_of(dat3));
        debug::print(&signer::address_of(&sig));


        // return sig
    }
}
