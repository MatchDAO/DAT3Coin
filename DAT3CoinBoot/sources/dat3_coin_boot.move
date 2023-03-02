/// this module deploy code to be used in main source code
module dat3::dat3_coin_boot {
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};

    use aptos_framework::code;

    #[test_only]
    use aptos_std::debug;


    const ERR_PERMISSIONS: u64 = 403;



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
        let year =50u128 /50;
        let m=1u128;

        let i=0u128;
        while (i < year) {
             m=m*2;
            i=i+1;
        };
        debug::print(&m );
       let mint= (((7200 as u128) / m ) as u64);
        debug::print(&mint );


        // return sig
    }
}
