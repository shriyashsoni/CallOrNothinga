import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'config.dart';

class ContractInterface {
  Web3Client? web3client;
  DeployedContract? contract;
  String? currentAccount;
  bool isInitialized = false;
  late Credentials credentials;

  ContractInterface();

  Future<void> initializeWithPrivateKey(String privateKey) async {
    try {
      // Initialize Web3
      final client = Client();
      web3client = Web3Client('http://127.0.0.1:8545', client);

      // Load contract ABI
      final abiString = await rootBundle.loadString('assets/PokerGame.json');
      print('Loaded ABI string: ${abiString.substring(0, 100)}...'); // Print first 100 chars
      
      final abiJson = jsonDecode(abiString);
      print('Parsed ABI JSON: ${jsonEncode(abiJson).substring(0, 100)}...'); // Print first 100 chars
      
      final abi = abiJson['abi'];
      if (abi == null) {
        throw Exception('Invalid contract ABI: ABI field not found in JSON.');
      }
      
      print('ABI functions:');
      final parsedAbi = ContractAbi.fromJson(jsonEncode(abi), 'PokerGame');
      for (var function in parsedAbi.functions) {
        print('- ${function.name} (${function.type})');
      }

      // Create contract instance
      contract = DeployedContract(
        parsedAbi,
        EthereumAddress.fromHex(Config.contractAddress),
      );

      // Print all available functions in the contract instance
      print('\nContract functions:');
      for (var function in contract!.functions) {
        print('- ${function.name} (${function.type})');
      }

      // Get credentials from private key
      credentials = EthPrivateKey.fromHex(privateKey);
      currentAccount = (await credentials.extractAddress()).hex;
      print('Connected with account: $currentAccount');

      print('Contract initialized with address: ${Config.contractAddress}');
      isInitialized = true;

      // Check if player is already in game
      final isInGame = await isPlayerInGame(currentAccount!);
      if (isInGame) {
        print('Player is already in the game');
      }
    } catch (e) {
      print('Contract initialization error: $e');
      throw Exception('Failed to initialize contract: $e');
    }
  }

  Future<bool> isPlayerInGame(String address) async {
    try {
      if (!isInitialized) {
        return false;
      }
      final function = contract!.function('isPlayerInGame');
      final result = await web3client!.call(
        sender: EthereumAddress.fromHex(currentAccount!),
        contract: contract!,
        function: function,
        params: [EthereumAddress.fromHex(address)],
      );
      if (result.isEmpty) {
        return false;
      }
      return result[0] as bool;
    } catch (e) {
      print('Error checking if player is in game: $e');
      return false;
    }
  }

  Future<int> getCurrentGameId() async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }

      final function = contract!.function('currentGameId');
      print('Calling function: ${function.name}');
      final result = await web3client!.call(
        sender: EthereumAddress.fromHex(currentAccount!),
        contract: contract!,
        function: function,
        params: [],
      );

      print('Raw result from contract call: $result');
      if (result.isEmpty) {
        print('No game ID returned');
        return 0;
      }

      final gameId = (result[0] as BigInt).toInt();
      print('Current game ID: $gameId');
      return gameId;
    } catch (e) {
      print('Error getting current game ID: $e');
      throw Exception('Failed to get current game ID: $e');
    }
  }

  Future<int> getPlayerGameId(String address) async {
    try {
      final function = contract!.function('playerGameId');
      final result = await web3client!.call(
        contract: contract!,
        function: function,
        params: [EthereumAddress.fromHex(address)],
      );
      final gameId = result.isNotEmpty ? (result[0] as BigInt).toInt() : 0;
      print('Player ${address} is in game: $gameId');
      return gameId;
    } catch (e) {
      print('Error getting player game ID: $e');
      return 0;
    }
  }

  Future<bool> createNewGame() async {
    if (!isInitialized) {
      throw Exception('Contract not initialized. Please connect wallet first.');
    }

    try {
      print('Creating new game...');
      final function = contract!.function('createNewGame');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Transaction successful, hash: ${receipt.transactionHash}');
      
      // Wait a bit for the state to update
      await Future.delayed(const Duration(seconds: 2));
      
      // Verify game was created by checking new game ID
      final newGameId = await getCurrentGameId();
      if (newGameId == 0) {
        throw Exception('Failed to create game - no game ID returned');
      }
      
      print('Successfully created new game with ID: $newGameId');
      return true;
    } catch (e) {
      print('Error creating game: $e');
      throw Exception('Failed to create game: $e');
    }
  }

  Future<bool> joinGame(BigInt buyInAmount) async {
    if (!isInitialized) {
      throw Exception('Contract not initialized. Please connect wallet first.');
    }

    try {
      // Check if player is already in game
      final isInGame = await isPlayerInGame(currentAccount!);
      print('Is player already in game? $isInGame');
      
      if (isInGame) {
        throw Exception('Already in game');
      }

      // Get current game ID and verify it
      final gameId = await getCurrentGameId();
      if (gameId == 0) {
        throw Exception('No active game found');
      }
      print('Current game ID before join: $gameId');
      
      // Get number of players to check if game is full
      final numPlayers = await getNumberOfPlayers(gameId);
      if (numPlayers >= 2) {
        throw Exception('Game is full');
      }
      
      print('Joining game with ID: $gameId');
      print('Buy-in amount: $buyInAmount');
      print('Current account: $currentAccount');

      final joinFunction = contract!.function('joinGame');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: joinFunction,
          parameters: [BigInt.from(gameId)],
          value: EtherAmount.fromBigInt(EtherUnit.wei, buyInAmount),
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for join game transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully joined game with transaction hash: ${receipt.transactionHash}');
      
      // Wait for state to update and verify the phase has changed
      int attempts = 0;
      const maxAttempts = 10;
      bool stateUpdated = false;
      
      while (attempts < maxAttempts && !stateUpdated) {
        await Future.delayed(const Duration(seconds: 1));
        
        // Get player's game ID after joining
        final playerGameId = await getPlayerGameId(currentAccount!);
        print('Player game ID after joining: $playerGameId');
        
        final newGameState = await getGameState();
        if (newGameState != null) {
          final newPhase = newGameState['phase'] as int;
          final newNumPlayers = newGameState['numPlayers'] as int;
          final newFirstPlayer = newGameState['firstPlayer'] as EthereumAddress;
          final isFirstPlayer = newGameState['isFirstPlayer'] as bool;
          
          print('Game state after joining (attempt ${attempts + 1}):');
          print('- Game ID: $playerGameId');
          print('- Phase: ${await getPhaseText(newPhase)}');
          print('- Number of players: $newNumPlayers');
          print('- First Player: ${newFirstPlayer.hex}');
          print('- Am I first player? $isFirstPlayer');
          
          if (playerGameId > 0 && newNumPlayers > 0) {
            stateUpdated = true;
            break;
          }
        }
        attempts++;
      }
      
      if (!stateUpdated) {
        print('Warning: Game state did not update after joining');
      }
      
      return true;
    } catch (e) {
      print('Error joining game: $e');
      throw Exception('Failed to join game: $e');
    }
  }

  Future<bool> submitEncryptedDeck(List<int> encryptedDeck) async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }

      // Log game state before submission
      final gameState = await getGameState();
      print('Game state before submission:');
      print('- Game ID: $gameId');
      print('- Phase: ${gameState?['phase']}');
      print('- First Player: ${gameState?['firstPlayer']}');
      print('- Current Account: $currentAccount');
      print('- Is First Player: ${await isFirstPlayer(currentAccount!)}');
      
      print('Submitting encrypted deck for game $gameId: $encryptedDeck');
      final function = contract!.function('submitEncryptedDeck');
      
      // Print function details
      print('Function details:');
      print('- Name: ${function.name}');
      print('- Inputs: ${function.parameters.map((p) => '${p.name}: ${p.type}').join(', ')}');
      print('- Outputs: ${function.outputs.map((p) => '${p.name}: ${p.type}').join(', ')}');
      
      // Convert the list of ints to BigInts with proper uint256 values
      final encryptedDeckBigInt = encryptedDeck.map((i) => BigInt.from(i)).toList();
      
      // Print parameters being sent
      print('Sending parameters:');
      print('- gameId: ${BigInt.from(gameId)}');
      print('- encryptedDeck: $encryptedDeckBigInt');
      
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [BigInt.from(gameId), encryptedDeckBigInt],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully submitted encrypted deck with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error submitting encrypted deck: $e');
      throw Exception('Failed to submit encrypted deck: $e');
    }
  }

  Future<bool> selectCards(List<int> firstPlayerCards, List<int> secondPlayerCards, List<int> flopCards, int encryptionSeed) async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }
      print('Selecting cards for game $gameId:');
      print('First player cards: $firstPlayerCards');
      print('Second player cards: $secondPlayerCards');
      print('Flop cards: $flopCards');
      print('Encryption seed: $encryptionSeed');
      
      final function = contract!.function('selectCards');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [
            BigInt.from(gameId),
            firstPlayerCards.map((i) => BigInt.from(i)).toList(),
            secondPlayerCards.map((i) => BigInt.from(i)).toList(),
            flopCards.map((i) => BigInt.from(i)).toList(),
            BigInt.from(encryptionSeed)
          ],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully selected cards with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error selecting cards: $e');
      throw Exception('Failed to select cards: $e');
    }
  }

  Future<bool> decryptCards(List<int> decryptedCards, String forPlayer) async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }

      print('Decrypting cards for player: $forPlayer');
      print('Decrypted cards: $decryptedCards');
      
      // Convert card indices to BigInt
      final decryptedCardsBigInt = decryptedCards.map((i) => BigInt.from(i)).toList();
      
      final function = contract!.function('decryptCards');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [decryptedCardsBigInt, EthereumAddress.fromHex(forPlayer)],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully decrypted cards with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error decrypting cards: $e');
      throw Exception('Failed to decrypt cards: $e');
    }
  }

  Future<bool> selectOwnCards(List<int> selectedIndices) async {
    try {
      final function = contract!.function('selectOwnCards');
      final result = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [selectedIndices],
        ),
        chainId: 31337,
      );
      return true;
    } catch (e) {
      print('Error selecting own cards: $e');
      return false;
    }
  }

  Future<bool> submitSortedDeck(List<int> sortedDeck) async {
    try {
      final function = contract!.function('submitSortedDeck');
      final result = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [sortedDeck],
        ),
        chainId: 31337,
      );
      return true;
    } catch (e) {
      print('Error submitting sorted deck: $e');
      return false;
    }
  }

  Future<bool> dealCommunityCards() async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }

      print('Dealing community cards for game $gameId');
      
      final function = contract!.function('dealCommunityCards');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [BigInt.from(gameId)],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully dealt community cards with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error dealing community cards: $e');
      return false;
    }
  }

  Future<bool> placeBet(BigInt betAmount) async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }

      print('Placing bet of $betAmount wei for game $gameId');
      final function = contract!.function('placeBet');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [BigInt.from(gameId)],
          value: EtherAmount.fromBigInt(EtherUnit.wei, betAmount),
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully placed bet with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error placing bet: $e');
      throw Exception('Failed to place bet: $e');
    }
  }

  Future<bool> fold() async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }

      print('Folding in game $gameId');
      final function = contract!.function('fold');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [BigInt.from(gameId)],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully folded with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error folding: $e');
      throw Exception('Failed to fold: $e');
    }
  }

  Future<Map<String, dynamic>?> getGameState() async {
    try {
      if (!isInitialized || currentAccount == null) {
        print('Contract not initialized or no current account');
        return null;
      }

      final playerGameId = await getPlayerGameId(currentAccount!);
      print('Got game ID for ${currentAccount!}: $playerGameId');
      if (playerGameId == 0) {
        print('No active game found for ${currentAccount!}');
        return null;
      }

      // Get basic game state
      final basicStateFunction = contract!.function('getGameBasicState');
      print('Getting game state for game $playerGameId');
      final basicState = await web3client!.call(
        contract: contract!,
        function: basicStateFunction,
        params: [BigInt.from(playerGameId)],
      );

      print('Raw result from getGameBasicState: $basicState');
      if (basicState.isEmpty) {
        print('Empty result from contract call');
        return null;
      }

      try {
        // Convert all numeric values safely
        int convertToInt(dynamic value) {
          if (value is BigInt) return value.toInt();
          if (value is int) return value;
          if (value is String) return int.tryParse(value) ?? 0;
          return 0;
        }

        // Explicitly handle uint8 values
        int convertToUint8(dynamic value) {
          final intValue = convertToInt(value);
          return intValue & 0xFF; // Ensure value is in uint8 range
        }

        final pot = basicState[0] as BigInt;
        final currentBet = basicState[1] as BigInt;
        final currentPlayer = convertToUint8(basicState[2]);
        final roundDeadline = basicState[3] as BigInt;
        final phase = convertToUint8(basicState[4]);
        final firstPlayer = basicState[5] is String 
            ? EthereumAddress.fromHex(basicState[5].toString())
            : basicState[5] as EthereumAddress;
        final lastBetAmount = basicState[6] as BigInt;
        final communityCardsDealt = convertToUint8(basicState[7]);
        final numPlayers = convertToUint8(basicState[8]);

        // Get first player status
        final isFirstPlayerResult = await isFirstPlayer(currentAccount!);

        print('First player in game $playerGameId: ${firstPlayer.hex}');
        print('Current player (${currentAccount!}) is first player: $isFirstPlayerResult');
        print('Number of players: $numPlayers');
        print('Game phase: ${await getPhaseText(phase)}');

        // Get community cards
        final communityCardsFunction = contract!.function('getGameCommunityCards');
        final communityCardsResult = await web3client!.call(
          contract: contract!,
          function: communityCardsFunction,
          params: [BigInt.from(playerGameId)],
        );
        final communityCards = (communityCardsResult[0] as List<dynamic>)
            .map((e) => convertToInt(e))
            .toList();

        // Get player cards
        final playerCardsFunction = contract!.function('getGamePlayerCards');
        final playerCardsResult = await web3client!.call(
          contract: contract!,
          function: playerCardsFunction,
          params: [BigInt.from(playerGameId)],
        );
        final firstPlayerCards = (playerCardsResult[0] as List<dynamic>)
            .map((e) => convertToInt(e))
            .toList();
        final secondPlayerCards = (playerCardsResult[1] as List<dynamic>)
            .map((e) => convertToInt(e))
            .toList();

        // Get encrypted deck
        final encryptedDeckFunction = contract!.function('getGameEncryptedDeck');
        final encryptedDeckResult = await web3client!.call(
          contract: contract!,
          function: encryptedDeckFunction,
          params: [BigInt.from(playerGameId)],
        );
        final encryptedDeck = (encryptedDeckResult[0] as List<dynamic>)
            .map((e) => e as BigInt)
            .toList();

        // Get flop cards
        final flopCardsFunction = contract!.function('getGameFlopCards');
        final flopCardsResult = await web3client!.call(
          contract: contract!,
          function: flopCardsFunction,
          params: [BigInt.from(playerGameId)],
        );
        final flopCards = (flopCardsResult[0] as List<dynamic>)
            .map((e) => convertToInt(e))
            .toList();

        return {
          'gameId': playerGameId,
          'communityCards': communityCards,
          'pot': pot,
          'currentBet': currentBet,
          'currentPlayer': currentPlayer,
          'roundDeadline': roundDeadline,
          'phase': phase,
          'firstPlayer': firstPlayer,
          'lastBetAmount': lastBetAmount,
          'communityCardsDealt': communityCardsDealt,
          'numPlayers': numPlayers,
          'isFirstPlayer': isFirstPlayerResult,
          'firstPlayerCards': firstPlayerCards,
          'secondPlayerCards': secondPlayerCards,
          'encryptedDeck': encryptedDeck,
          'encryptedFlopCards': flopCards
        };
      } catch (e) {
        print('Error parsing game state: $e');
        print('Raw result was: $basicState');
        return null;
      }
    } catch (e, stackTrace) {
      print('Error getting game state: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<dynamic>> getPlayerInfo(String address) async {
    try {
      final function = contract!.function('players');
      final result = await web3client!.call(
        contract: contract!,
        function: function,
        params: [],
      );
      
      for (var player in result) {
        if (player[0].toString().toLowerCase() == address.toLowerCase()) {
          return player;
        }
      }
      return [];
    } catch (e) {
      print('Error getting player info: $e');
      return [];
    }
  }

  Future<int> getCurrentPhase() async {
    try {
      final gameState = await getGameState();
      if (gameState == null) return 0;
      return gameState['phase'] as int;
    } catch (e) {
      print('Error getting current phase: $e');
      return 0; // Return Joining phase as default
    }
  }

  Future<String> getPhaseText(int phase) async {
    switch (phase) {
      case 0:
        return 'Joining';
      case 1:
        return 'First Player Encryption';
      case 2:
        return 'Second Player Selection';
      case 3:
        return 'Pre-Flop Betting';
      case 4:
        return 'Flop Dealing';
      case 5:
        return 'Flop Decryption (Player 1)';
      case 6:
        return 'Flop Decryption (Player 2)';
      case 7:
        return 'Flop Betting';
      case 8:
        return 'Turn Dealing';
      case 9:
        return 'Turn Decryption (Player 1)';
      case 10:
        return 'Turn Decryption (Player 2)';
      case 11:
        return 'Turn Betting';
      case 12:
        return 'River Dealing';
      case 13:
        return 'River Decryption (Player 1)';
      case 14:
        return 'River Decryption (Player 2)';
      case 15:
        return 'River Betting';
      case 16:
        return 'Showdown';
      default:
        return 'Unknown Phase';
    }
  }

  Future<bool> isFirstPlayer(String address) async {
    try {
      if (!isInitialized) {
        return false;
      }
      final function = contract!.function('isFirstPlayer');
      final result = await web3client!.call(
        contract: contract!,
        function: function,
        params: [EthereumAddress.fromHex(address)],
      );
      if (result.isEmpty) {
        return false;
      }
      return result[0] as bool;
    } catch (e) {
      print('Error checking if player is first player: $e');
      return false;
    }
  }

  Future<bool> decryptCommunityCards(List<int> decryptedCards) async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }
      
      final gameId = await getPlayerGameId(currentAccount!);
      if (gameId == 0) {
        throw Exception('No active game found');
      }

      final gameState = await getGameState();
      if (gameState == null) {
        throw Exception('Could not get game state');
      }

      final phase = gameState['phase'] as int;
      String phaseText = '';
      if (phase == 5) phaseText = 'flop';
      else if (phase == 8) phaseText = 'turn';
      else if (phase == 11) phaseText = 'river';
      else throw Exception('Not in a decryption phase');

      print('Decrypting $phaseText cards: $decryptedCards');
      
      final function = contract!.function('decryptCommunityCards');
      final transaction = await web3client!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract!,
          function: function,
          parameters: [BigInt.from(gameId), decryptedCards.map((i) => BigInt.from(i)).toList()],
        ),
        chainId: 31337,
      );
      
      // Wait for transaction to be mined
      print('Waiting for transaction receipt...');
      TransactionReceipt? receipt;
      do {
        receipt = await web3client!.getTransactionReceipt(transaction);
        if (receipt == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (receipt == null);
      
      print('Successfully decrypted $phaseText cards with hash: ${receipt.transactionHash}');
      return true;
    } catch (e) {
      print('Error decrypting community cards: $e');
      throw Exception('Failed to decrypt community cards: $e');
    }
  }

  Future<int> getNumberOfPlayers(int gameId) async {
    try {
      if (!isInitialized) {
        throw Exception('Contract not initialized');
      }

      final function = contract!.function('getNumberOfPlayers');
      final result = await web3client!.call(
        contract: contract!,
        function: function,
        params: [BigInt.from(gameId)],
      );

      if (result.isEmpty) {
        return 0;
      }

      return (result[0] as BigInt).toInt();
    } catch (e) {
      print('Error getting number of players: $e');
      return 0;
    }
  }
} 