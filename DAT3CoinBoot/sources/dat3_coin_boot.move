/// this module deploy code to be used in main source code
module dat3::dat3_coin_boot {
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};

    use aptos_framework::code;


    use std::error;

    const ERR_PERMISSIONS: u64 = 403;


    struct BootResourceSignerStore has key {
        sinCap: SignerCapability,
    }

    const PERMISSION_DENIED: u64 = 1000;
    const INVALID_ARGUMENT: u64 = 105;

    // Deploy code & store tempo resource signer
    public entry fun initializeWithResourceAccount(
        admin: &signer,
        metadata: vector<u8>,
        byteCode: vector<u8>,
        seed: vector<u8>
    ) {
        assert!(signer::address_of(admin) == @dat3, error::permission_denied(PERMISSION_DENIED));
        let (resourceSigner, sinCap) =
            account::create_resource_account(admin, seed);

        code::publish_package_txn(&resourceSigner, metadata, vector[byteCode]);
        move_to(admin, BootResourceSignerStore { sinCap });
    }

    /// Destroys temporary storage for resource account signer capability and returns signer capability.
    /// It needs for initialization of .
    public fun retrieveResourceSignerCap(aptospadAdmin: &signer): SignerCapability acquires BootResourceSignerStore {
        assert!(signer::address_of(aptospadAdmin) == @dat3, error::permission_denied(PERMISSION_DENIED));

        let BootResourceSignerStore { sinCap } = move_from<BootResourceSignerStore>(
            signer::address_of(aptospadAdmin)
        );
        sinCap
    }

    const NUM_VEC: vector<u8> = b"0123456789";

    // #[test_only]
    // use std::string;
    // #[test_only]
    // use std::string::String;
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_std::debug;

    // #[test_only]
    // fun intToString(_n: u64): String {
    //     let v = _n;
    //     let str_b = b"";
    //     if (v > 0) {
    //         while (v > 0) {
    //             let rest = v % 10;
    //             v = v / 10;
    //             vector::push_back(&mut str_b, *vector::borrow(&NUM_VEC, rest));
    //         };
    //         vector::reverse(&mut str_b);
    //     } else {
    //         vector::append(&mut str_b, b"0");
    //     };
    //     string::utf8(str_b)
    // }
    #[test(dat3 = @dat3)]
    fun test_resource_account(dat3: &signer)
    {
        let (_, signer_cap) =
            account::create_resource_account(dat3, b"dat3");
        let (_, signer_cap2) =
            account::create_resource_account(dat3, b"dat3_nft");
        let sig = account::create_signer_with_capability(&signer_cap);
        let sig2 = account::create_signer_with_capability(&signer_cap2);
        debug::print(&signer::address_of(dat3));
        debug::print(&signer::address_of(&sig));
        debug::print(&signer::address_of(&sig2));

        //mint
        let year = 50u128 / 50;
        let m = 1u128;
        let i = 0u128;
        while (i < year) {
            m = m * 2;
            i = i + 1;
        };
        debug::print(&m);
        let mint = (((7200 as u128) / m) as u64);
        debug::print(&mint);
        let uuuu = vector::empty<u64>();
        vector::push_back(&mut uuuu, 1);
        vector::push_back(&mut uuuu, 2);
        vector::push_back(&mut uuuu, 3);
        vector::push_back(&mut uuuu, 4);
        vector::push_back(&mut uuuu, 5);
        vector::push_back(&mut uuuu, 6);
        let leng = vector::length(&uuuu);
        let j = 0u64;
        while (j < leng) {
            let temp = vector::borrow(&uuuu, j);
            let os = *temp;
            if ((*temp as u128) % 2 == 0) {
                vector::swap_remove(&mut uuuu, j);
                j = j - 1;
                if ((leng - j) > 1) {
                    leng = leng - 1;
                };
            };
            debug::print(&os);
            debug::print(&uuuu);
            j = j + 1;
        };
    }
}
