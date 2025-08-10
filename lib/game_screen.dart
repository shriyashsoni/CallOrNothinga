import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web3dart/web3dart.dart';
import 'contract_interface.dart';
import 'config.dart';
import 'dart:async';

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
            final newIsFirstPlayer = gameState['firstPlayer'] != null && 
                gameState['firstPlayer'].toString().toLowerCase() == 
                _contractInterface.currentAccount!.toLowerCase();
                
            // Only update state if something changed
            if (newPhase != prevPhase || newIsFirstPlayer != _isFirstPlayer) {
              final phaseText = await _contractInterface.getPhaseText(newPhase);
              setState(() {
                _currentPhase = newPhase;
                _isFirstPlayer = newIsFirstPlayer;
                _phaseText = phaseText;
              });
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
      setState(() {
        _isInGame = true;
      });
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
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
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
                              if (_isInGame)
                                Text('Role: ${_isFirstPlayer ? "First Player" : "Second Player"}'),
                            ],
                          ),
                        ),
                      if (!_isInGame)
                        ElevatedButton(
                          onPressed: _joinGame,
                          child: const Text('Join Game'),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
} 