import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/foundation.dart';
import 'contract_interface.dart';
import 'config.dart';
import 'dart:async';
import 'dart:math';

class CardDeckWidget extends StatefulWidget {
  final Function(List<int>) onSubmit;
  final bool isEnabled;

  const CardDeckWidget({
    super.key,
    required this.onSubmit,
    this.isEnabled = true,
  });

  @override
  State<CardDeckWidget> createState() => _CardDeckWidgetState();
}

class _CardDeckWidgetState extends State<CardDeckWidget> {
  List<int> deck = List.generate(52, (i) => i);
  List<int> encryptedDeck = [];
  bool isEncrypted = false;
  final TextEditingController _seedController = TextEditingController();
  List<int> usedSeeds = [];

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  String getCardString(int cardIndex) {
    final suits = ['♠', '♣', '♥', '♦'];
    final values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    
    final suit = suits[cardIndex ~/ 13];
    final value = values[cardIndex % 13];
    
    return '$value$suit';
  }

  Color getCardColor(int cardIndex) {
    return cardIndex ~/ 13 >= 2 ? Colors.red : Colors.black;
  }

  void shuffleDeck() {
    if (!isEncrypted) {
      setState(() {
        deck.shuffle(Random.secure());
      });
    }
  }

  void encryptDeck() {
    if (!isEncrypted) {
      final seed = int.tryParse(_seedController.text);
      if (seed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number for encryption')),
        );
        return;
      }
      
      setState(() {
        // Identity encryption - just use the current deck order
        encryptedDeck = List.from(deck);
        isEncrypted = true;
        usedSeeds.add(seed);
        _seedController.clear();
      });
    }
  }

  void generateRandomSeed() {
    final random = Random.secure();
    final seed = random.nextInt(1000000); // Generate a random 6-digit number
    _seedController.text = seed.toString();
  }

  void submitDeck() {
    if (isEncrypted) {
      widget.onSubmit(encryptedDeck);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEncrypted ? 'Encrypted Deck' : 'Card Deck',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!isEncrypted) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _seedController,
                    decoration: const InputDecoration(
                      labelText: 'Encryption Key',
                      hintText: 'Enter a number for encryption',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: generateRandomSeed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text('Generate Random Key'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (usedSeeds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Used Encryption Keys:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(usedSeeds.join(', ')),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 13,
                childAspectRatio: 0.7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 52,
              itemBuilder: (context, index) {
                final cardIndex = deck[index];
                return Card(
                  color: isEncrypted ? Colors.blue.shade100 : Colors.white,
                  child: Center(
                    child: isEncrypted 
                      ? const Icon(Icons.lock, color: Colors.blue)
                      : Text(
                          getCardString(cardIndex),
                          style: TextStyle(
                            color: getCardColor(cardIndex),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: widget.isEnabled && !isEncrypted ? shuffleDeck : null,
                child: const Text('Shuffle'),
              ),
              ElevatedButton(
                onPressed: widget.isEnabled && !isEncrypted ? encryptDeck : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Encrypt'),
              ),
              ElevatedButton(
                onPressed: widget.isEnabled && isEncrypted ? submitDeck : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CardSelectionWidget extends StatefulWidget {
  final Function(List<int>, List<int>, List<int>, int) onSubmit;
  final bool isEnabled;

  const CardSelectionWidget({
    super.key,
    required this.onSubmit,
    this.isEnabled = true,
  });

  @override
  State<CardSelectionWidget> createState() => _CardSelectionWidgetState();
}

class _CardSelectionWidgetState extends State<CardSelectionWidget> {
  List<int> firstPlayerCards = [];
  List<int> secondPlayerCards = [];
  List<int> flopCards = [];
  final TextEditingController _seedController = TextEditingController();
  bool isEncrypted = true; // Always encrypted for second player

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  void selectCard(int index, String type) {
    setState(() {
      switch (type) {
        case 'first_player':
          if (firstPlayerCards.contains(index)) {
            firstPlayerCards.remove(index);
          } else if (firstPlayerCards.length < 2) {
            firstPlayerCards.add(index);
          }
          break;
        case 'second_player':
          if (secondPlayerCards.contains(index)) {
            secondPlayerCards.remove(index);
          } else if (secondPlayerCards.length < 2) {
            secondPlayerCards.add(index);
          }
          break;
        case 'flop':
          if (flopCards.contains(index)) {
            flopCards.remove(index);
          } else if (flopCards.length < 5) {
            flopCards.add(index);
          }
          break;
      }
    });
  }

  void generateRandomSeed() {
    final random = Random.secure();
    final seed = random.nextInt(1000000); // Generate a random 6-digit number
    _seedController.text = seed.toString();
  }

  Color getSelectionColor(int index) {
    if (firstPlayerCards.contains(index)) return Colors.green.shade200;
    if (secondPlayerCards.contains(index)) return Colors.blue.shade200;
    if (flopCards.contains(index)) return Colors.purple.shade200;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Cards',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _seedController,
                  decoration: const InputDecoration(
                    labelText: 'Encryption Seed',
                    hintText: 'Enter a number for encryption',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: generateRandomSeed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Generate Random Seed'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Card Selection Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('First Player Cards', Colors.green.shade200),
              _buildLegendItem('Your Cards', Colors.blue.shade200),
              _buildLegendItem('Flop Cards', Colors.purple.shade200),
            ],
          ),
          const SizedBox(height: 16),
          // Single Card Deck
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 13,
                childAspectRatio: 0.7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 52,
              itemBuilder: (context, index) {
                final isSelected = firstPlayerCards.contains(index) ||
                    secondPlayerCards.contains(index) ||
                    flopCards.contains(index);
                return GestureDetector(
                  onTap: widget.isEnabled ? () {
                    if (firstPlayerCards.length < 2) {
                      selectCard(index, 'first_player');
                    } else if (secondPlayerCards.length < 2) {
                      selectCard(index, 'second_player');
                    } else if (flopCards.length < 5) {
                      selectCard(index, 'flop');
                    }
                  } : null,
                  child: Card(
                    color: getSelectionColor(index),
                    child: Center(
                      child: isSelected 
                        ? const Icon(Icons.lock, color: Colors.grey)
                        : const Icon(Icons.lock_outline, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Selected: ${firstPlayerCards.length}/2 first player, ${secondPlayerCards.length}/2 your cards, ${flopCards.length}/5 flop',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.isEnabled && 
                      firstPlayerCards.length == 2 && 
                      secondPlayerCards.length == 2 && 
                      flopCards.length == 5 &&
                      _seedController.text.isNotEmpty
                ? () {
                    print('Submitting cards:');
                    print('First player cards: $firstPlayerCards');
                    print('Second player cards: $secondPlayerCards');
                    print('Flop cards: $flopCards');
                    print('Seed: ${_seedController.text}');
                    
                    if (_seedController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an encryption seed')),
                      );
                      return;
                    }
                    
                    final seed = int.parse(_seedController.text);
                    widget.onSubmit(firstPlayerCards, secondPlayerCards, flopCards, seed);
                  }
                : () {
                    print('Submit button disabled. Conditions:');
                    print('- widget.isEnabled: ${widget.isEnabled}');
                    print('- firstPlayerCards.length: ${firstPlayerCards.length}/2');
                    print('- secondPlayerCards.length: ${secondPlayerCards.length}/2');
                    print('- flopCards.length: ${flopCards.length}/5');
                    print('- Has seed: ${_seedController.text.isNotEmpty}');
                    
                    String message = 'Please complete: ';
                    if (firstPlayerCards.length < 2) message += 'First player cards, ';
                    if (secondPlayerCards.length < 2) message += 'Your cards, ';
                    if (flopCards.length < 5) message += 'Flop cards, ';
                    if (_seedController.text.isEmpty) message += 'Encryption seed, ';
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message.substring(0, message.length - 2))),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Submit Selected Cards',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class GameCardsWidget extends StatelessWidget {
  final List<int>? playerCards;
  final List<int>? communityCards;
  final bool isFirstPlayer;
  final int currentPhase;

  const GameCardsWidget({
    super.key,
    this.playerCards,
    this.communityCards,
    required this.isFirstPlayer,
    required this.currentPhase,
  });

  String getCardString(int cardIndex) {
    final suits = ['♠', '♣', '♥', '♦'];
    final values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    
    final suit = suits[cardIndex ~/ 13];
    final value = values[cardIndex % 13];
    
    return '$value$suit';
  }

  Color getCardColor(int cardIndex) {
    return cardIndex ~/ 13 >= 2 ? Colors.red : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Player's cards
        if (playerCards != null) ...[
          const Text(
            'Your Cards',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: playerCards!.map((cardIndex) {
              return Card(
                color: Colors.white,
                child: Container(
                  width: 60,
                  height: 84,
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      getCardString(cardIndex),
                      style: TextStyle(
                        color: getCardColor(cardIndex),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        // Community cards
        if (communityCards != null) ...[
          const Text(
            'Community Cards',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              if (index < (communityCards?.length ?? 0)) {
                final cardIndex = communityCards![index];
                return Card(
                  color: Colors.white,
                  child: Container(
                    width: 60,
                    height: 84,
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        getCardString(cardIndex),
                        style: TextStyle(
                          color: getCardColor(cardIndex),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return Card(
                  color: Colors.blue.shade100,
                  child: Container(
                    width: 60,
                    height: 84,
                    padding: const EdgeInsets.all(8),
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.blue),
                    ),
                  ),
                );
              }
            }),
          ),
        ],
      ],
    );
  }
}

class BettingWidget extends StatefulWidget {
  final Function(BigInt) onBet;
  final Function() onFold;
  final BigInt currentBet;
  final BigInt pot;
  final bool isEnabled;

  const BettingWidget({
    super.key,
    required this.onBet,
    required this.onFold,
    required this.currentBet,
    required this.pot,
    this.isEnabled = true,
  });

  @override
  State<BettingWidget> createState() => _BettingWidgetState();
}

class _BettingWidgetState extends State<BettingWidget> {
  final TextEditingController _raiseController = TextEditingController();
  
  @override
  void dispose() {
    _raiseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Current Pot: ${widget.pot.toString()} wei',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Bet to Call: ${widget.currentBet.toString()} wei',
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isEnabled ? () {
                    widget.onBet(widget.currentBet);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _raiseController,
                  decoration: const InputDecoration(
                    labelText: 'Raise Amount (wei)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: widget.isEnabled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isEnabled ? () {
                    final raiseAmount = BigInt.tryParse(_raiseController.text);
                    if (raiseAmount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid raise amount')),
                      );
                      return;
                    }
                    if (raiseAmount <= widget.currentBet) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Raise must be greater than the current bet')),
                      );
                      return;
                    }
                    widget.onBet(raiseAmount);
                    _raiseController.clear();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Raise'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.isEnabled ? widget.onFold : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Fold'),
          ),
        ],
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ContractInterface _contractInterface = ContractInterface();
  final TextEditingController _privateKeyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _connectedAddress;
  bool _isConnected = false;
  bool _isInGame = false;
  int _currentPhase = 0;
  bool _isFirstPlayer = false;
  Timer? _stateCheckTimer;
  String _phaseText = 'Not in game';
  int? _currentGameId;
  int? _playerGameId;
  bool _isMyTurn = false;
  List<int>? playerCards;
  List<int>? communityCards;
  BigInt? _currentBet;
  BigInt? _pot;

  @override
  void initState() {
    super.initState();
    _startStateCheck();
  }

  @override
  void dispose() {
    _stateCheckTimer?.cancel();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _startStateCheck() {
    _stateCheckTimer?.cancel();
    _stateCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isConnected || !mounted) return;

      try {
        // Cache previous values for comparison
        final prevIsInGame = _isInGame;
        final prevPhase = _currentPhase;
        final prevGameId = _currentGameId;
        
        // Only check game ID if not in game
        if (!_isInGame) {
          final gameId = await _contractInterface.getCurrentGameId();
          if (gameId != prevGameId) {
            setState(() {
              _currentGameId = gameId;
            });
          }
        }
        
        // Check if player is in game
        final isInGame = await _contractInterface.isPlayerInGame(_contractInterface.currentAccount!);
        if (isInGame != prevIsInGame) {
          setState(() {
            _isInGame = isInGame;
            if (!isInGame) {
              _phaseText = 'Not in game';
            }
          });
        }
        
        // Only get game state if in game
        if (_isInGame) {
          final gameState = await _contractInterface.getGameState();
          if (mounted && gameState != null) {
            final newPhase = gameState['phase'] as int;
            final firstPlayer = gameState['firstPlayer'] as EthereumAddress;
            final newIsFirstPlayer = firstPlayer.hex.toLowerCase() == 
                _contractInterface.currentAccount!.toLowerCase();
            final currentPlayer = gameState['currentPlayer'] as int;
            final isMyTurn = (currentPlayer == 0 && newIsFirstPlayer) || 
                           (currentPlayer == 1 && !newIsFirstPlayer);
            final newCurrentBet = gameState['currentBet'] as BigInt;
            final newPot = gameState['pot'] as BigInt;

            // Get player's cards if available
            List<int>? newPlayerCards;
            if (newIsFirstPlayer && gameState['firstPlayerCards'] != null) {
              newPlayerCards = (gameState['firstPlayerCards'] as List<dynamic>).cast<int>();
            } else if (!newIsFirstPlayer && gameState['secondPlayerCards'] != null) {
              newPlayerCards = (gameState['secondPlayerCards'] as List<dynamic>).cast<int>();
            }

            // Get community cards if available
            List<int>? newCommunityCards;
            if (gameState['communityCards'] != null) {
              newCommunityCards = (gameState['communityCards'] as List<dynamic>)
                  .where((card) => card > 0)
                  .cast<int>()
                  .toList();
            }
                
            // Only update state if something changed
            if (newPhase != _currentPhase || 
                newIsFirstPlayer != _isFirstPlayer || 
                isMyTurn != _isMyTurn ||
                !listEquals(newPlayerCards, playerCards) ||
                !listEquals(newCommunityCards, communityCards)) {
              final phaseText = await _contractInterface.getPhaseText(newPhase);
              if (mounted) {
                setState(() {
                  _currentPhase = newPhase;
                  _isFirstPlayer = newIsFirstPlayer;
                  _phaseText = phaseText;
                  _isMyTurn = isMyTurn;
                  _currentBet = newCurrentBet;
                  _pot = newPot;
                  playerCards = newPlayerCards;
                  communityCards = newCommunityCards;
                });
              }
            }
          }
        }
      } catch (e) {
        print('Error updating game state: $e');
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
          });
        }
      }
    });
  }

  Future<void> _handlePhaseAction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_currentPhase) {
        case 1: // First Player Encryption
          if (_isFirstPlayer) {
            final random = Random.secure();
            final encryptedDeck = List<int>.generate(52, (i) => i)..shuffle(random);
            await _contractInterface.submitEncryptedDeck(encryptedDeck);
          }
          break;

        case 2: // Second Player Card Selection
          // Handled by CardSelectionWidget
          break;

        case 3: // PreFlopBetting
          if (_isFirstPlayer) {
            final gameState = await _contractInterface.getGameState();
            if (gameState != null && gameState['secondPlayerCards'] != null) {
              final secondPlayerCards = (gameState['secondPlayerCards'] as List<dynamic>).cast<int>();
              final players = gameState['players'] as List<dynamic>;
              if (players.length > 1) {
                final secondPlayerAddress = players[1]['addr'] as String;
                await _contractInterface.decryptCards(secondPlayerCards, secondPlayerAddress);
              }
            }
          }
          break;

        case 4: // FlopDealing
          if (_isFirstPlayer) {
            await _contractInterface.dealCommunityCards();
          }
          break;

        // Flop Decryption Phases
        case 5: // FlopDecryptionP1
        case 6: // FlopDecryptionP2
          final gameState = await _contractInterface.getGameState();
          if (gameState != null && gameState['encryptedFlopCards'] != null) {
            final flopCards = (gameState['encryptedFlopCards'] as List<dynamic>)
                .take(3)
                .cast<int>()
                .toList();
            await _contractInterface.decryptCommunityCards(flopCards);
          }
          break;

        case 8: // TurnDealing
          if (_isFirstPlayer) {
            await _contractInterface.dealCommunityCards();
          }
          break;

        // Turn Decryption Phases
        case 9:  // TurnDecryptionP1
        case 10: // TurnDecryptionP2
          final gameState = await _contractInterface.getGameState();
          if (gameState != null && gameState['encryptedFlopCards'] != null) {
            final turnCard = [(gameState['encryptedFlopCards'] as List<dynamic>)[3] as int];
            await _contractInterface.decryptCommunityCards(turnCard);
          }
          break;

        case 12: // RiverDealing
          if (_isFirstPlayer) {
            await _contractInterface.dealCommunityCards();
          }
          break;

        // River Decryption Phases
        case 13: // RiverDecryptionP1
        case 14: // RiverDecryptionP2
          final gameState = await _contractInterface.getGameState();
          if (gameState != null && gameState['encryptedFlopCards'] != null) {
            final riverCard = [(gameState['encryptedFlopCards'] as List<dynamic>)[4] as int];
            await _contractInterface.decryptCommunityCards(riverCard);
          }
          break;
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildActionButton() {
    if (!_isConnected || !_isInGame) return const SizedBox.shrink();

    // For the encryption phase, show the card deck widget
    if (_currentPhase == 1 && _isFirstPlayer) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: CardDeckWidget(
          onSubmit: (encryptedDeck) async {
            try {
              setState(() => _isLoading = true);
              await _contractInterface.submitEncryptedDeck(encryptedDeck);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully submitted encrypted deck!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            }
          },
        ),
      );
    }

    // For second player card selection phase
    if (_currentPhase == 2 && !_isFirstPlayer) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: CardSelectionWidget(
          onSubmit: (firstPlayerCards, secondPlayerCards, flopCards, seed) async {
            try {
              setState(() => _isLoading = true);
              await _contractInterface.selectCards(firstPlayerCards, secondPlayerCards, flopCards, seed);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cards selected successfully!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            }
          },
        ),
      );
    }

    // For betting phases
    if (_isBettingPhase(_currentPhase) && _isMyTurn) {
      return BettingWidget(
        onBet: (betAmount) async {
          try {
            setState(() => _isLoading = true);
            await _contractInterface.placeBet(betAmount);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bet placed successfully!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }
        },
        onFold: () async {
          try {
            setState(() => _isLoading = true);
            await _contractInterface.fold();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully folded')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }
        },
        currentBet: _currentBet ?? BigInt.zero,
        pot: _pot ?? BigInt.zero,
        isEnabled: _isMyTurn,
      );
    }

    // For dealing and decryption phases
    if ((_isDealingPhase(_currentPhase) && _isFirstPlayer) || 
        _isDecryptionPhase(_currentPhase)) {
      return ElevatedButton(
        onPressed: _handlePhaseAction,
        child: Text(_isDealingPhase(_currentPhase) ? 'Deal Cards' : 'Decrypt Cards'),
      );
    }

    return const SizedBox.shrink();
  }

  bool _isBettingPhase(int phase) {
    return phase == 3 || phase == 6 || phase == 9 || phase == 12;
  }

  bool _isDealingPhase(int phase) {
    return phase == 4 || phase == 7 || phase == 10;
  }

  bool _isDecryptionPhase(int phase) {
    return phase == 5 || phase == 6 || // Flop decryption (P1 and P2)
           phase == 9 || phase == 10 || // Turn decryption (P1 and P2)
           phase == 13 || phase == 14;  // River decryption (P1 and P2)
  }

  Future<void> _connectWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final privateKey = _privateKeyController.text.trim();
      if (privateKey.isEmpty) {
        throw Exception('Please enter a private key');
      }
      
      if (!privateKey.startsWith('0x')) {
        throw Exception('Private key must start with 0x');
      }

      await _contractInterface.initializeWithPrivateKey(privateKey);
      final isInGame = await _contractInterface.isPlayerInGame(_contractInterface.currentAccount!);
      
      setState(() {
        _connectedAddress = _contractInterface.currentAccount;
        _isConnected = true;
        _isInGame = isInGame;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final buyInAmount = BigInt.from(1000000000000000000); // 1 ETH
      await _contractInterface.joinGame(buyInAmount);
      
      // Force immediate state refresh after joining
      final gameState = await _contractInterface.getGameState();
      if (gameState != null) {
        final newPhase = gameState['phase'] as int;
        final firstPlayer = gameState['firstPlayer'] as EthereumAddress;
        final newIsFirstPlayer = firstPlayer.hex.toLowerCase() == 
            _contractInterface.currentAccount!.toLowerCase();
        final currentPlayer = gameState['currentPlayer'] as int;
        final isMyTurn = (currentPlayer == 0 && newIsFirstPlayer) || 
                       (currentPlayer == 1 && !newIsFirstPlayer);
        
        setState(() {
          _isInGame = true;
          _currentPhase = newPhase;
          _isFirstPlayer = newIsFirstPlayer;
          _isMyTurn = isMyTurn;
        });
        
        _contractInterface.getPhaseText(newPhase).then((text) {
          if (mounted) {
            setState(() {
              _phaseText = text;
            });
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the game!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Game'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: $_errorMessage',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (!_isConnected) ...[
                      const Text(
                        'Enter your private key to connect:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _privateKeyController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Private Key',
                          hintText: '0x...',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _connectWallet,
                        child: const Text('Connect Wallet'),
                      ),
                    ] else ...[
                      if (_connectedAddress != null)
                        Column(
                          children: [
                            Text('Connected: $_connectedAddress'),
                            const SizedBox(height: 8),
                            Text(
                              _isInGame 
                                ? 'Status: In game' 
                                : 'Status: Not in game',
                              style: TextStyle(
                                color: _isInGame ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_currentGameId != null)
                              Text('Current Game ID: $_currentGameId'),
                            Text('Phase: $_phaseText'),
                            if (_isInGame) ...[
                              Text('Role: ${_isFirstPlayer ? "First Player" : "Second Player"}'),
                              const SizedBox(height: 16),
                              if (_currentPhase >= 3) // Show cards after PreFlopBetting phase
                                GameCardsWidget(
                                  playerCards: playerCards,
                                  communityCards: communityCards,
                                  isFirstPlayer: _isFirstPlayer,
                                  currentPhase: _currentPhase,
                                ),
                            ],
                          ],
                        ),
                      if (!_isInGame)
                        ElevatedButton(
                          onPressed: _joinGame,
                          child: const Text('Join Game'),
                        ),
                      _buildActionButton(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
} 