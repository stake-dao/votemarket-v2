// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";

import "src/oracle/Oracle.sol";
import "src/oracle/OracleLens.sol";
import "src/verifiers/Verifier.sol";
import "src/interfaces/IGaugeController.sol";

abstract contract ProofCorrectnessTest is Test {
    Oracle oracle;
    Verifier verifier;
    address GAUGE_CONTROLLER;
    bool public immutable isV2;

    address account;
    address gauge;
    uint256 blockNumber;

    uint256 lastUserVoteSlot;
    uint256 userSlopeSlot;
    uint256 weightSlot;

    constructor(
        address _gaugeController,
        address _account,
        address _gauge,
        uint256 _blockNumber,
        uint256 _lastUserVoteSlot,
        uint256 _userSlopeSlot,
        uint256 _weightSlot,
        bool _isV2
    ) {
        GAUGE_CONTROLLER = _gaugeController;
        account = _account;
        gauge = _gauge;
        blockNumber = _blockNumber;

        lastUserVoteSlot = _lastUserVoteSlot;
        userSlopeSlot = _userSlopeSlot;
        weightSlot = _weightSlot;
        isV2 = _isV2;
    }

    function setUp() public {
        vm.createSelectFork("mainnet", blockNumber);

        oracle = new Oracle(address(this));

        verifier = new Verifier(address(oracle), GAUGE_CONTROLLER, lastUserVoteSlot, userSlopeSlot, weightSlot);

        oracle.setAuthorizedDataProvider(address(verifier));
        oracle.setAuthorizedBlockNumberProvider(address(this));
        oracle.setAuthorizedBlockNumberProvider(address(verifier));
    }

    function testInitialSetup() public {
        assertEq(address(verifier.ORACLE()), address(oracle));
        assertEq(verifier.SOURCE_GAUGE_CONTROLLER_HASH(), keccak256(abi.encodePacked(GAUGE_CONTROLLER)));

        assertEq(oracle.authorizedDataProviders(address(verifier)), true);
        assertEq(oracle.authorizedBlockNumberProviders(address(this)), true);
        assertEq(oracle.authorizedBlockNumberProviders(address(verifier)), true);

        oracle.revokeAuthorizedDataProvider(address(verifier));
        oracle.revokeAuthorizedBlockNumberProvider(address(this));
        oracle.revokeAuthorizedBlockNumberProvider(address(verifier));

        assertEq(oracle.authorizedDataProviders(address(verifier)), false);
        assertEq(oracle.authorizedBlockNumberProviders(address(this)), false);
        assertEq(oracle.authorizedBlockNumberProviders(address(verifier)), false);

        Verifier newVerifier =
            new Verifier(address(oracle), GAUGE_CONTROLLER, lastUserVoteSlot, userSlopeSlot, weightSlot);
        assertEq(address(newVerifier.ORACLE()), address(oracle));
        assertEq(newVerifier.SOURCE_GAUGE_CONTROLLER_HASH(), keccak256(abi.encodePacked(GAUGE_CONTROLLER)));
        assertEq(newVerifier.WEIGHT_MAPPING_SLOT(), weightSlot);
        assertEq(newVerifier.LAST_VOTE_MAPPING_SLOT(), lastUserVoteSlot);
        assertEq(newVerifier.USER_SLOPE_MAPPING_SLOT(), userSlopeSlot);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Oracle.AUTH_GOVERNANCE_ONLY.selector);
        oracle.transferGovernance(address(0));

        vm.expectRevert(Oracle.ZERO_ADDRESS.selector);
        oracle.transferGovernance(address(0));

        oracle.transferGovernance(address(0xBEEF));

        vm.expectRevert(Oracle.AUTH_GOVERNANCE_ONLY.selector);
        oracle.acceptGovernance();

        assertEq(oracle.governance(), address(this));
        assertEq(oracle.futureGovernance(), address(0xBEEF));

        vm.prank(address(0xBEEF));
        oracle.acceptGovernance();

        assertEq(oracle.governance(), address(0xBEEF));
        assertEq(oracle.futureGovernance(), address(0));
    }

    function testGetProofParams() public {
        uint256 epoch = block.timestamp / 1 weeks * 1 weeks;

        uint256 lastUserVote = IGaugeController(GAUGE_CONTROLLER).last_user_vote(account, gauge);
        (uint256 slope,, uint256 end) = IGaugeController(GAUGE_CONTROLLER).vote_user_slopes(account, gauge);
        (uint256 bias_,) = IGaugeController(GAUGE_CONTROLLER).points_weight(gauge, epoch);

        // Generate proofs for both gauge and account
        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory controllerProof, bytes memory storageProofRlp) =
            generateAndEncodeProof(account, gauge, epoch, true);

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            epoch,
            StateProofVerifier.BlockHeader({
                hash: blockHash,
                stateRootHash: bytes32(0),
                number: block.number,
                timestamp: block.timestamp
            })
        );

        verifier.setBlockData(blockHeaderRlp, controllerProof);

        IOracle.Point memory weight = verifier.setPointData(gauge, epoch, storageProofRlp);

        // (,,, storageProofRlp) = generateAndEncodeProof(account, gauge, epoch, false);

        storageProofRlp =
            hex"f917d5f907e9f90211a0ca21c1cc6a78be9159d59bfd319443b8544176a15204b42ef0070c04c0ffda48a06c90bf8b73eacb5fa33bf6cb83330f45efd7b0015bc785fd8703d3a697b7812ca033bd22fcf917e50efb1edd45c6f4839d697d70c93b2b18e48f571a86260a00dba0e551bb4ee069c79e6d193453ce2aa3cd8a941b6fb92ecc46c9df511627ecdbdaa0b2cd567869b04ee445558272cf7cb76feecc6c1d3ddeffd2204fad9fd7226b3fa0a04957d98b0f4112915ed2b4ef043395d4c05a356adcfaf6e21be58d2237ebc3a08a42b63452b9eaca9905d95443c3ab68b2f78d69c9907d0f9ae00bbd649d5b67a059c6895a408af7d7d2481eb2fcf8e7496f5b59f94be69f7843bb3410684134e5a011f804e69fd93a986b913c6436ae1ffbba9c929754db2e4af5c24b8c21442eb6a04c6c4565f34ab95bb38e41c99d76f9c16a5c16ee6d49878c73f7e49c66817a79a0041d009c5c8e7e0dc7a0fcb8947db9b6260e3eea563d5ac5b2e168c3c54edb38a0a9730acc780c9b9d5efd71d4b3c09b1565fffbefe4c9281bbfb153cb43b88216a07c2924a338741e5b722bf768b4770c70db9a4a45471a0738763f96170753b089a0b7cac964368b639e1154b7831c09ed9d83f9a3a2fb7445cdb7ef0e07b1df5152a01e3095b63a1a8aa6e623f50a172cea779b3d1761985767cec963c0f77591c6e6a03d5b40880f2608e2ec0fa2f710b75b50d1d411ce79440f9c58233ee7d598477780f90211a0037db0088c55b212a4e8cff80611a6d99a9d3287a5ab6cb10a3f72f924acdcdda00ad3292a7496270f378519e6d1213ac3d2cd2c1c575ad3647c32e3fa667229b7a03d32b111a82f192d931d7d3c47f2672d21733a5d7705d79ba1528f59873282e0a06b07aa2385554f42419301739d1e835a4ad7be3674e1ffa088a2f8a15d415aaca0e8d24d06bca3ea997668b93b29a8d4a046668d621ed7884a2a3c3f0fd2658827a094d7b285a2d0aa77c578337433785544f9b6b092b1fd0a3da025589356e695f9a0d1592bdc4752cf69cff5222781e4d7f378efbe998e0152066ae859600395e505a0fd459f10eae613bfe0be8c63bcd25377d2b1b66769acdd41b7ed940929aa8bfaa069b9a165c7d74326db6040dadd770aac74ed1bf0f67ae65f337000f77f50f784a0387aafeab4d9938c2fb02de6df26add4768b9cc97d25b76d40192b80e6d362e3a0a9576dc5ed0739c08e47b32404b02cf8deaa3d936df0467c12efa1643d9f3c36a0c54444caeaf79d801fed5383f18a18b5037f4a5bf812f51048e5bdda40ea02c4a00a55629c521e6e624165af306fb069996d35e770a68ee54021b73491b032ac94a0d62d7f98853b4a9ccacd74f85a1753d1a159b6603852d77c670f2b345c04c76ba0bf64b814198b4a384cddf94c889b8e8d69321249db92b6e9d38d79193daf3527a0f3663e07c316d6dcb473e6479d3ea1630f2ec356e4f679c51bb64a24fde1f9b980f90211a071031cfccae4214026298208a6b93603a421d7557b1f72beb0b791f7c484bb47a098e6d16d5056c9d51559ac0169ce6568f82ab8aa7a3186e90d9c86894907a369a0cbd6f30817c515de6c393c37e3dc509f0580db1b109d373e2533176f2c661e64a0bd5b7d3d57d6d9920ebf4989ec8f0d3a6e760c765ef9e4d4de6e31a7b3197304a058129a0fe4ccbb15c5a360fe9f7931b3de90dc17c2285ed0c34e871243b7dbdba0e3db6d5a359ef48147358b78a9cb488e87b6a58c373bd192d145024e923ed8c1a023e2ded07b21b923c20e10afc3d2283a7698c556a5fe7d5dd37ee172d5a2eefea03d40ccccb145a904069b2e0ea28456184bc5a8744cd699d2e814ceb37f5751cca0b0ecaf7b5f7179b30130e5ce671bfb7ddc3aaaa5a70ed46b32cf611fc68ec2d1a036e5806058c79d4178a6d3d7a0c2f02884cd75ea4c155d05a61779a128b9d378a0170b7727ac5357f85b69b1c05e196dee8524ccc0caea650f393afbe11ec0d01aa09e20bcce5bf4275f71474e0fb5025ec5390339efebc4ddbb7069ac8737fdf7ffa027cc6e2c6246fc2f9fa620aab00b70aa375151ac962b01fbce1f24790c2008a1a0d3fbb53b4d3658d2f7edd568facd22e65080b89d15c965a8ae0ea4cf3afc8cf3a0b96226523b73a2e7002b96a6a976b7a6eed934708383634f9e314cbb17afd524a0d7023b084c0b4e829dee88a93b01b8134621fbf753154dbefa43c3105cfc4f0e80f90131a04bc6637c8f33c12865fbe485ad76716b27b60f3b6bfb84fbeac2c48ffa3a5c24a0c8ed03add2b424b7b16eb21218172a643d9607c7abf200d34249b4943def4833a049d9ebc50dbac5d34666e44ef3e73e13af0b4bd5fd208bd04e057f0419fe61d180a09e89fd62fa2f6031b59ddaffbf34303b939427324bd8fa6857fe6e5516bbe09da027623567d94bb3131693baab90d400b37b393b8c715d68516f48df51eeee9ddc80808080a0537ca65c808856b8a2cda237f21f569a97280eb8680d28b2b554e5030c0e6b68a02c1f17838fba906cf16b81b5520f11bb5b94a402cc4d11a5918fb942d2dc191aa0efae9b4e6edf91c0520fe5e9b51352a0a5d9333d1012d625cdafdd647ad3008880a066fbe1c0795ea7274c6e9fae30cddabc8ee384a45fed383d59b8da4bdf54061a8080f85180808080a027f4d044a761f951e3a320504b3c71f537f44a029e151803541de5455d5199b080808080a06592742569595891aaf0e7d27a4bdcccf111bb19df4685b8c6b1c4ca09f4a2f380808080808080e59e3484288e972d2c50967f339a02a85028592421208f2d1439ce875919e00a858466b0eefbf9086cf90211a0ca21c1cc6a78be9159d59bfd319443b8544176a15204b42ef0070c04c0ffda48a06c90bf8b73eacb5fa33bf6cb83330f45efd7b0015bc785fd8703d3a697b7812ca033bd22fcf917e50efb1edd45c6f4839d697d70c93b2b18e48f571a86260a00dba0e551bb4ee069c79e6d193453ce2aa3cd8a941b6fb92ecc46c9df511627ecdbdaa0b2cd567869b04ee445558272cf7cb76feecc6c1d3ddeffd2204fad9fd7226b3fa0a04957d98b0f4112915ed2b4ef043395d4c05a356adcfaf6e21be58d2237ebc3a08a42b63452b9eaca9905d95443c3ab68b2f78d69c9907d0f9ae00bbd649d5b67a059c6895a408af7d7d2481eb2fcf8e7496f5b59f94be69f7843bb3410684134e5a011f804e69fd93a986b913c6436ae1ffbba9c929754db2e4af5c24b8c21442eb6a04c6c4565f34ab95bb38e41c99d76f9c16a5c16ee6d49878c73f7e49c66817a79a0041d009c5c8e7e0dc7a0fcb8947db9b6260e3eea563d5ac5b2e168c3c54edb38a0a9730acc780c9b9d5efd71d4b3c09b1565fffbefe4c9281bbfb153cb43b88216a07c2924a338741e5b722bf768b4770c70db9a4a45471a0738763f96170753b089a0b7cac964368b639e1154b7831c09ed9d83f9a3a2fb7445cdb7ef0e07b1df5152a01e3095b63a1a8aa6e623f50a172cea779b3d1761985767cec963c0f77591c6e6a03d5b40880f2608e2ec0fa2f710b75b50d1d411ce79440f9c58233ee7d598477780f90211a02db1e0e52d89f9543a54e85f14fad7c328b2d5cffc9847e4feded9e4da896501a00d149e653053bd886a98e0d50410dffb8b7c7773730f042e729e027142654113a00f34612adaa753e6438dd509b5bba399ebd7c87e116356c273d82137fa93a2faa0ad1376d035964fa79ddc310bcf068d69d9c4622f84664e94563285b618f47198a073445f82a87e14e9ec003959f2d8a407453543059d9778c8055321acf1ea215ca05356ea422cf6e8626147bfaecedee81b045029cfe9647450fb30998a16137692a022bc8f5995ae6177591b9c899060acd6bf6b92890091a4345a94b1c8ed899805a02e8ee086993b150652a8b02c897896a4c19de7d9816c41dce90387de1bc19701a01dbedb3a53e851ded0be9fe6b926b9fa21fd32caf0547a8f736a48a0c1c0cf01a0b79e1938ce288f33f91bb7658bce7d1ffdef5097d0391b8535e53b02ac80b47da03b9944692a02e72cb255c04507be64e05b6f2d96623c64c3c7ddf8039273cfd3a07f99f434a05de36292f65d6383616ee01ccea2842e30a420e428011545f62d54a0298e3f5a80c557f7f0f8def2ff5aeabfcf63711d01321fc261233eda27c44100a08c03bcecc29e636456b33b8a9bd0f5045f159cdf9ffd57bd8b51acde33489fbaa0a6a3bdba6eb23b9d5e39b5e2df791b3d10452254a8d19eb127ad281899c07247a09a99a820c7de985085f612d3e810f34ebd88ee7d9e4d4231bea5978018b52bbf80f90211a0410a51ddbbca2871108a59adbe6df3f561ad54adc74d2a35f82dad927d9d2e6fa0778ecd167e94ff12b67feb1b487accd92b065486b446e04008a691dcce2b943fa03251dbfd13c1f5164e15535820f73251dbd21ed3a08c36dde64781eb0a8ad2eca048567d6fe39212168a9bc96ef2559abbe02400967634ebe5bc23523e2ad17c64a01f72a8caebb5eb985cb30105df799d9f60c70d1582123310d7e4cbb5fa1bdecea0f076f2ea4afa64427a908e6531381fb62aded086c6030ebc5ed0d878b0a01812a08776517fad443a74e92190fb90d7e916035c8356366136a3ebf204cefbe17edaa0d356753a50aa302b969306521e85d71e69bed22ab9269573f7a11e9fac6ec30ca004de3c66ea946361b202f2b86633e08be6af0fab774807fb1cb68d685125fcefa016cda0dbef3f7a58c457580b54f5944eb4c12e5e1db4f0efc8f31ae57128650da030e85abe7598cc303ad77c2e3a8a1f6f942706040c4490f0da4aa9b803933350a05edb215ea4b03928db858a5cc3c14333de245c94ad8d0bf2280c518e443984a2a07e0cb248eb88d8d6f4d4e8809eda374cc521e99892bc0e4cb4fe9af57d1d1aa2a06f7d8947657076581117619a6fb0a56034b9befa1f361ab0955c14be6c5e619ea0d54b7286e20be5100e720555659ef6a501dbf1410e1114438aaf52ff6ba9d58ea0f7533b61cbe409e68c25776d8448159907cfab56b2e7dc65c21fce85f131ed4f80f90191a0013a5581f02c68931054f0a016ee21c8cc4b15d720e5bf53accebbea4b3eb337a0c49b88896e82ec1a525cb6566e66b691416bdbf510cc87a5d3250c1d18b27cd5a0a5d886cf13e721d3eb8d6ccef3ab815f86de3f997381ea84dc99dec45238f050a01d3169e6160307ac7d28bbe8af531edbb4ffb826c83775266871ee2534d8ba75a0a3827055116b335f1558cf5b142c99ec8f390f5eabdc651705274ddf1da9d944a0468eb395a1e0df1afbb22f83d0ca865f5a4d0048f5184f2d1ec3bae7578ffbeaa0df0685680b0fa868a6d3be35458b495962d44fe2575a3c3c3f391b0ff77f5373808080a03992988c18071391e28c849bc082863d2a00faabe58872de4908298fbc120d24a01d830254b42374f2919c89876d50d1b45c059233a166c6ae4771a0ffa802956880a0acf59d06241e34fd3f4873ad2e6e89a8058b41538132a4a33ca165e46325cc84a0b0c5cb2374c379d86ebdf709d1b6205af8f6a0ccb8e7ccf1531902d1e2f641daa0a4e5c9ecb066403b1c3126dff1725966bf3e266c3646c9fb39a3a04467a2513f80f871a0a647b8c7e6b95b882c6cd935ad4cbae746513a4310e95795fcab6b041dd89b4f8080808080a0cc6122347862b94f89ad378358f6e24a158aeb6a03b4355bdaea5687ce43b9d08080808080a09d0732008a2206eb1c5d9acedebb65a6828ec9c2e82ac0237a29c5c8c4892e3180808080e89e3e1de8af03e9c85d65fdb853e438d084fdbd8088e167e139c7da1378c76d88870289870b39b228f90777f90211a0ca21c1cc6a78be9159d59bfd319443b8544176a15204b42ef0070c04c0ffda48a06c90bf8b73eacb5fa33bf6cb83330f45efd7b0015bc785fd8703d3a697b7812ca033bd22fcf917e50efb1edd45c6f4839d697d70c93b2b18e48f571a86260a00dba0e551bb4ee069c79e6d193453ce2aa3cd8a941b6fb92ecc46c9df511627ecdbdaa0b2cd567869b04ee445558272cf7cb76feecc6c1d3ddeffd2204fad9fd7226b3fa0a04957d98b0f4112915ed2b4ef043395d4c05a356adcfaf6e21be58d2237ebc3a08a42b63452b9eaca9905d95443c3ab68b2f78d69c9907d0f9ae00bbd649d5b67a059c6895a408af7d7d2481eb2fcf8e7496f5b59f94be69f7843bb3410684134e5a011f804e69fd93a986b913c6436ae1ffbba9c929754db2e4af5c24b8c21442eb6a04c6c4565f34ab95bb38e41c99d76f9c16a5c16ee6d49878c73f7e49c66817a79a0041d009c5c8e7e0dc7a0fcb8947db9b6260e3eea563d5ac5b2e168c3c54edb38a0a9730acc780c9b9d5efd71d4b3c09b1565fffbefe4c9281bbfb153cb43b88216a07c2924a338741e5b722bf768b4770c70db9a4a45471a0738763f96170753b089a0b7cac964368b639e1154b7831c09ed9d83f9a3a2fb7445cdb7ef0e07b1df5152a01e3095b63a1a8aa6e623f50a172cea779b3d1761985767cec963c0f77591c6e6a03d5b40880f2608e2ec0fa2f710b75b50d1d411ce79440f9c58233ee7d598477780f90211a0037db0088c55b212a4e8cff80611a6d99a9d3287a5ab6cb10a3f72f924acdcdda00ad3292a7496270f378519e6d1213ac3d2cd2c1c575ad3647c32e3fa667229b7a03d32b111a82f192d931d7d3c47f2672d21733a5d7705d79ba1528f59873282e0a06b07aa2385554f42419301739d1e835a4ad7be3674e1ffa088a2f8a15d415aaca0e8d24d06bca3ea997668b93b29a8d4a046668d621ed7884a2a3c3f0fd2658827a094d7b285a2d0aa77c578337433785544f9b6b092b1fd0a3da025589356e695f9a0d1592bdc4752cf69cff5222781e4d7f378efbe998e0152066ae859600395e505a0fd459f10eae613bfe0be8c63bcd25377d2b1b66769acdd41b7ed940929aa8bfaa069b9a165c7d74326db6040dadd770aac74ed1bf0f67ae65f337000f77f50f784a0387aafeab4d9938c2fb02de6df26add4768b9cc97d25b76d40192b80e6d362e3a0a9576dc5ed0739c08e47b32404b02cf8deaa3d936df0467c12efa1643d9f3c36a0c54444caeaf79d801fed5383f18a18b5037f4a5bf812f51048e5bdda40ea02c4a00a55629c521e6e624165af306fb069996d35e770a68ee54021b73491b032ac94a0d62d7f98853b4a9ccacd74f85a1753d1a159b6603852d77c670f2b345c04c76ba0bf64b814198b4a384cddf94c889b8e8d69321249db92b6e9d38d79193daf3527a0f3663e07c316d6dcb473e6479d3ea1630f2ec356e4f679c51bb64a24fde1f9b980f90211a070aff271cf47995df1499c6cb17888718b621efca86ce1b4e01e975e9a11b895a059e83eced286482f9d9aa426e2831d4fb0edb3f66efa51b438b63b163a15373fa032eb8aecdcaa2ac9ae6fa143c1f74c8dc5dffd5efecd2dcdf99b7d7457318a23a077e2c12285e6ef06cf1b1345b77e8d09a4a4861c715134de02ef93c4d25ea46aa0b0a0e5365f0c7435868254d084fb53ae74737995319880067e031d3c5dd42beca0ba7074356ccceee6f39f7c24203c78007d0ecaf59382863951b838f6b5746a80a01064141409ac1e8c2516a818310716ab79e09bf3b43c63076a25caecc5d7913ca0539ffb37207c56cdc4a409a4b90542e14ce4e3f0f3d9efec48a7fbed423e4163a00ddf30a0f97bb26ae5d69058d2b29c9f6543e0a6fa1157da09148a772c9cd25da0ee688f6401e1eece3b4279a7bcf90b16d532df51d8eb9e7434f107ea6fa16796a0a3d5b7126e77db7a3b2b6e4ca3720d66c76737af10219004f2bc2f903ed97e58a0044d788ab998a7ce3f1d9d0e2ff7a1b011f156834b2ab583021bb55b26d45a62a069b19468cc61fc3245ce7d5e247fa0e94d58096d52024e7978dfcfe053c09ca2a0a4abcb8ab210edfa61be71a20d57067d9e12197afee5260d30cfdc30f712fdbea0dbf5f21b986f41e4ab27f088904ec5a1b3db63a424842e34d73381b9261e4502a032ad61307dce0b4dcd92034d40a829493db2a1d1b2a2729d3199220e11b16c9480f9011180808080a0b86bbb7f5c97aa0f83c9b97389896402d962479972e88b804bcb1a102861cacea008c235294286f5f6dd052617e6cf97d09a602a065059967e8341511099e000c5a08e3595d8540c7e859266787cc6e5fca4e2693d1571b5740d58cc514dd4299b5ba0736c32bf330505b7dcbaef7c36d3cf33c05c870deee6563152271b7623436844a05941732b08cd847d60386288bb189b32db4cd05f268c4cf2cdfcdcb9f947551fa0d60b74c9519a732ef0e9c110060f4b5cbd598e2e855296c43f7445b918ef582aa093aa2fadf5a224bbba9484d226069c127d5ecabba70559270d270212d253917a808080a044e6be826ae6d59544d293bc78662c4d2e40e3f8fbeac8b8cab057c2d7f739188080e69f207bbd95a123e7504221e8f956574134b988336f3b46d4b4defd8f04560e718584688ab200";
        
        IOracle.VotedSlope memory userSlope = verifier.setAccountData(account, gauge, epoch, storageProofRlp);

        console.log("userSlope.slope", userSlope.slope);
        console.log("userSlope.end", userSlope.end);
        console.log("userSlope.lastVote", userSlope.lastVote);
        console.log("weight.bias", weight.bias);
        assertEq(userSlope.slope, slope);
        assertEq(userSlope.end, end);
        assertEq(userSlope.lastVote, lastUserVote);
        assertEq(weight.bias, bias_);
    }

    function testLens() public {
        OracleLens oracleLens = new OracleLens(address(oracle));
        assertEq(oracleLens.oracle(), address(oracle));

        uint256 epoch = block.timestamp / 1 weeks * 1 weeks;

        // Generate proofs for both gauge and account
        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory controllerProof, bytes memory storageProofRlp) =
            generateAndEncodeProof(account, gauge, epoch, true);

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            epoch,
            StateProofVerifier.BlockHeader({
                hash: blockHash,
                stateRootHash: bytes32(0),
                number: block.number,
                timestamp: block.timestamp
            })
        );

        vm.expectRevert(OracleLens.STATE_NOT_UPDATED.selector);
        oracleLens.getAccountVotes(account, gauge, epoch);

        vm.expectRevert(OracleLens.STATE_NOT_UPDATED.selector);
        oracleLens.getTotalVotes(gauge, epoch);

        vm.expectRevert(OracleLens.STATE_NOT_UPDATED.selector);
        oracleLens.isVoteValid(account, gauge, epoch);

        verifier.setBlockData(blockHeaderRlp, controllerProof);

        IOracle.Point memory weight = verifier.setPointData(gauge, epoch, storageProofRlp);
        (,,, storageProofRlp) = generateAndEncodeProof(account, gauge, epoch, false);
        IOracle.VotedSlope memory userSlope = verifier.setAccountData(account, gauge, epoch, storageProofRlp);

        uint256 totalVotes = oracleLens.getTotalVotes(gauge, epoch);
        uint256 accountVotes = oracleLens.getAccountVotes(account, gauge, epoch);

        assertEq(totalVotes, weight.bias);
        if (epoch >= userSlope.end) {
            assertEq(totalVotes, 0);
        } else {
            assertEq(accountVotes, userSlope.slope * (userSlope.end - epoch));
        }

        if (userSlope.slope > 0 && epoch <= userSlope.end && epoch > userSlope.lastVote) {
            assertTrue(oracleLens.isVoteValid(account, gauge, epoch));
        } else {
            assertFalse(oracleLens.isVoteValid(account, gauge, epoch));
        }
    }

    function generateAndEncodeProof(address account, address gauge, uint256 epoch, bool isGaugeProof)
        internal
        returns (bytes32, bytes memory, bytes memory, bytes memory)
    {
        uint256[] memory positions =
            isGaugeProof ? generateGaugeProof(gauge, epoch) : generateAccountProof(account, gauge);

        return getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, positions, block.number);
    }

    function generateGaugeProof(address gauge, uint256 epoch) internal view returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](1);

        uint256 pointWeightsPosition;
        if (isV2) {
            pointWeightsPosition = uint256(keccak256(abi.encode(keccak256(abi.encode(weightSlot, gauge)), epoch)));
        } else {
            pointWeightsPosition =
                uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(weightSlot, gauge)), epoch)))));
        }
        positions[0] = pointWeightsPosition;
        return positions;
    }

    function generateAccountProof(address account, address gauge) internal view returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](3);
        positions[0] = uint256(keccak256(abi.encode(keccak256(abi.encode(lastUserVoteSlot, account)), gauge)));

        uint256 voteUserSlopePosition;
        if (isV2) {
            voteUserSlopePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(userSlopeSlot, account)), gauge)));
        } else {
            voteUserSlopePosition = uint256(
                keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(userSlopeSlot, account)), gauge))))
            );
        }
        positions[1] = voteUserSlopePosition;
        positions[2] = voteUserSlopePosition + 2;

        return positions;
    }

    function getRLPEncodedProofs(
        string memory chain,
        address _account,
        uint256[] memory _positions,
        uint256 _blockNumber
    )
        internal
        returns (
            bytes32 _block_hash,
            bytes memory _block_header_rlp,
            bytes memory _account_proof,
            bytes memory _proof_rlp
        )
    {
        string[] memory inputs = new string[](5 + _positions.length);
        inputs[0] = "python3";
        inputs[1] = "test/python/generate_proof.py";
        inputs[2] = chain;
        inputs[3] = vm.toString(_account);
        inputs[4] = vm.toString(_blockNumber);
        for (uint256 i = 0; i < _positions.length; i++) {
            inputs[5 + i] = vm.toString(_positions[i]);
        }
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes, bytes));
    }
}
