#!/bin/bash
#deploy script
# Deploy step 1 :publish DAT3CoinBoot
# Deploy step 2 :compile veDAT3Coin
# Deploy step 3 :run dat3::dat3_coin_boot::initializeWithResourceAccount()
# Deploy step 4 :publish DAT3CoinBoot
# Deploy step 2 :init
# Deploy step 2 :compile veDAT3Coin
# 0K ,The goal is to get the deployer's signature,
DAT3='0x7d8320a497c20c1569cb6fecd7cc564f873de6316c462748a2b9c935e847384b'
PROFILE="devnet"
echo "dat3:'0x$DAT3'"
DAT3_PATH=`pwd `
COIN_PATH="$DAT3_PATH/veDAT3Coin"
BOOT_PATH="$DAT3_PATH/DAT3CoinBoot"
DAT3Pool="$DAT3_PATH/DAT3Pool"

cd $BOOT_PATH
echo " step 1 :bigin compile&publish boot :  -->`pwd`"
echo "`ls`"
echo `aptos move compile --package-dir "$BOOT_PATH"`
echo `aptos move publish --assume-yes --package-dir "$BOOT_PATH" `

echo "1-------------------------------------------------------------------------------------------"
cd $COIN_PATH
echo " step 2 :bigin compile veDAT3Coin : -->`pwd`"
echo "`ls`"
echo "aptos move compile --save-metadata --package-dir  $COIN_PATH "
echo `aptos move compile --save-metadata --package-dir  $COIN_PATH`
echo""

#hexdump -ve '1/1 "%.2x"' build/veDAT3Coin/package-metadata.bcs > meta.hex
#hexdump -ve '1/1 "%.2x"' build/veDAT3Coin/bytecode_modules/vedat3_coin.mv > coin.hex
#xxd -ps -c10000000 build/veDAT3Coin/package-metadata.bcs > meta.hex
#xxd -ps -c10000000 build/veDAT3Coin/bytecode_modules/vedat3_coin.mv > coin.hex
META=`xxd  -ps -c10000000  build/veDAT3Coin/package-metadata.bcs`
echo""
CODE=`xxd  -ps -c10000000  build/veDAT3Coin/bytecode_modules/vedat3_coin.mv`
echo "mata: $META"
echo "code: $CODE"
pause "done"
sleep 3 #
echo "2-------------------------------------------------------------------------------------------"
echo " step 3 :run dat3::dat3_coin_boot::initializeWithResourceAccount() "
echo " begin"
echo "aptos move run   --assume-yes --function-id $DAT3::dat3_coin_boot::initializeWithResourceAccount --args hex:$META  hex:$CODE"
echo""
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_coin_boot::initializeWithResourceAccount --args hex:"$META" hex:"$CODE" string:"dat3"`
sleep 2

cd $DAT3Pool
echo "aptos move compile --save-metadata --package-dir  $DAT3Pool "
echo `aptos move compile --save-metadata --package-dir  $DAT3Pool`
echo `aptos move publish --assume-yes --package-dir "$DAT3Pool" `
echo""
sleep 2
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_coin::init `
echo""
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_coin::mint_to --args u64:1000001  address:$DAT3`
echo""
sleep 2
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool::init_pool --type-args "0x1::aptos_coin::AptosCoin"`


echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool_routel::init --type-args "0x1::aptos_coin::AptosCoin"`