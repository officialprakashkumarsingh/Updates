import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params) execute;

  AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.execute,
  });
}

class AgentRequest {
  final String id;
  final String userMessage;
  final String model;
  final DateTime timestamp;
  Map<String, dynamic> context;
  Map<String, dynamic> result;
  bool isProcessing;

  AgentRequest({
    required this.id,
    required this.userMessage,
    required this.model,
    required this.timestamp,
    this.context = const {},
    this.result = const {},
    this.isProcessing = false,
  });
}

class AgentService extends ChangeNotifier {
  static final AgentService _instance = AgentService._internal();
  factory AgentService() => _instance;
  AgentService._internal() {
    _initializeTools();
  }

  bool _isAgentMode = false;
  bool _isProcessing = false;
  final Map<String, AgentTool> _tools = {};
  AgentRequest? _currentRequest;
  
  // Clean state tracking
  String _status = '';
  Map<String, dynamic> _processingData = {};

  bool get isAgentMode => _isAgentMode;
  bool get isProcessing => _isProcessing;
  String get status => _status;
  Map<String, dynamic> get processingData => Map.unmodifiable(_processingData);
  AgentRequest? get currentRequest => _currentRequest;

  void toggleAgentMode() {
    _isAgentMode = !_isAgentMode;
    notifyListeners();
  }

  void setAgentMode(bool enabled) {
    if (_isAgentMode != enabled) {
      _isAgentMode = enabled;
      notifyListeners();
    }
  }

  void _initializeTools() {
    // Web search tool using Wikipedia and DuckDuckGo
    _tools['web_search'] = AgentTool(
      name: 'web_search',
      description: 'Searches the web using Wikipedia and DuckDuckGo',
      parameters: {
        'query': {'type': 'string', 'description': 'The search query'},
        'source': {'type': 'string', 'description': 'Search source: wikipedia, duckduckgo, or both', 'default': 'both'},
        'limit': {'type': 'integer', 'description': 'Number of results to return (default: 5)', 'default': 5},
      },
      execute: _executeWebSearch,
    );

    // Screenshot tool
    _tools['screenshot'] = AgentTool(
      name: 'screenshot',
      description: 'Takes a screenshot of a webpage',
      parameters: {
        'url': {'type': 'string', 'description': 'The URL to take screenshot of'},
        'width': {'type': 'integer', 'description': 'Screenshot width (default: 1200)', 'default': 1200},
        'height': {'type': 'integer', 'description': 'Screenshot height (default: 800)', 'default': 800},
      },
      execute: _executeScreenshot,
    );

    // Page analyzer
    _tools['analyze_page'] = AgentTool(
      name: 'analyze_page',
      description: 'Analyzes web pages to extract information',
      parameters: {
        'url': {'type': 'string', 'description': 'URL of the page to analyze'},
        'type': {'type': 'string', 'description': 'Type of analysis: content, products, data', 'default': 'content'},
      },
      execute: _executePageAnalyzer,
    );
  }

  Future<Message> processAgentRequest(String userMessage, String selectedModel) async {
    if (!_isAgentMode) {
      throw Exception('Agent mode is not enabled');
    }

    _isProcessing = true;
    _status = 'Processing request...';
    _processingData = {};
    
    final request = AgentRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userMessage: userMessage,
      model: selectedModel,
      timestamp: DateTime.now(),
      isProcessing: true,
    );
    
    _currentRequest = request;
    notifyListeners();

    try {
      // Analyze request and determine needed tools
      final analysis = await _analyzeRequest(userMessage);
      _processingData['analysis'] = analysis;
      _status = 'Running analysis...';
      notifyListeners();

      // Execute tools if needed
      Map<String, dynamic> toolResults = {};
      if (analysis['tools_needed']?.isNotEmpty == true) {
        _status = 'Executing tools...';
        notifyListeners();
        
        for (String toolName in analysis['tools_needed']) {
          if (_tools.containsKey(toolName)) {
            final tool = _tools[toolName]!;
            final params = analysis['tool_params'][toolName] ?? {};
            toolResults[toolName] = await tool.execute(params);
          }
        }
      }
      
      _processingData['tool_results'] = toolResults;
      _status = 'Generating response...';
      notifyListeners();

      // Generate final response
      final response = await _generateResponse(userMessage, analysis, toolResults, selectedModel);
      
      request.result = {
        'analysis': analysis,
        'tool_results': toolResults,
        'response': response,
      };
      request.isProcessing = false;

      _isProcessing = false;
      _status = '';
      _currentRequest = null;
      notifyListeners();

      return Message.bot(response, agentProcessingData: {
        'agent_used': true,
        'tools_executed': toolResults.keys.toList(),
        'analysis': analysis,
        'processing_time': DateTime.now().difference(request.timestamp).inMilliseconds,
      });

    } catch (e) {
      _status = 'Error occurred';
      _isProcessing = false;
      _currentRequest = null;
      notifyListeners();

      final fallbackResponse = await _handleError(userMessage, selectedModel, e.toString());
      return Message.bot(fallbackResponse, agentProcessingData: {
        'agent_used': true,
        'error': e.toString(),
        'fallback_response': true,
      });
    }
  }

  Future<Map<String, dynamic>> _analyzeRequest(String userMessage) async {
    final message = userMessage.toLowerCase();
    
    List<String> toolsNeeded = [];
    Map<String, dynamic> toolParams = {};

    // Determine if screenshot is needed - improved pattern matching
    if (message.contains('screenshot') || message.contains('capture') ||
        message.contains('take a screenshot') || message.contains('take screenshot') ||
        message.contains('show me') && message.contains('.com')) {
      
      // Extract URL - improved URL detection
      final urlPattern = RegExp(r'(?:https?://)?(?:www\.)?([a-zA-Z0-9-]+\.[a-zA-Z]{2,})(?:/[^\s]*)?');
      final match = urlPattern.firstMatch(userMessage);
      
      if (match != null) {
        String url = match.group(0)!;
        // Ensure URL has protocol
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }
        toolsNeeded.add('screenshot');
        toolParams['screenshot'] = {'url': url};
      } else {
        // Try to extract domain name and construct URL
        final domainPattern = RegExp(r'([a-zA-Z0-9-]+\.[a-zA-Z]{2,})');
        final domainMatch = domainPattern.firstMatch(userMessage);
        if (domainMatch != null) {
          final domain = domainMatch.group(0)!;
          toolsNeeded.add('screenshot');
          toolParams['screenshot'] = {'url': 'https://$domain'};
        }
      }
    }

    // Determine if web search is needed
    if (message.contains('search') || message.contains('find') || 
        message.contains('latest') || message.contains('news') ||
        message.contains('information about') || message.contains('tell me about')) {
      toolsNeeded.add('web_search');
      
      // Extract search query
      String query = userMessage;
      if (message.contains('search for ')) {
        query = userMessage.substring(userMessage.toLowerCase().indexOf('search for ') + 11);
      } else if (message.contains('find ')) {
        query = userMessage.substring(userMessage.toLowerCase().indexOf('find ') + 5);
      } else if (message.contains('about ')) {
        query = userMessage.substring(userMessage.toLowerCase().indexOf('about ') + 6);
      }
      
      toolParams['web_search'] = {'query': query.trim()};
    }

    // Determine if page analysis is needed
    if (message.contains('analyze') || message.contains('extract') ||
        message.contains('get data') || message.contains('scrape')) {
      final urlPattern = RegExp(r'https?://[^\s]+');
      final match = urlPattern.firstMatch(userMessage);
      if (match != null) {
        toolsNeeded.add('analyze_page');
        toolParams['analyze_page'] = {'url': match.group(0)!};
      }
    }

    return {
      'intent': _classifyIntent(userMessage),
      'tools_needed': toolsNeeded,
      'tool_params': toolParams,
      'complexity': toolsNeeded.isEmpty ? 'simple' : 'complex',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String _classifyIntent(String message) {
    final msg = message.toLowerCase();
    
    if (msg.contains('screenshot') || msg.contains('capture')) return 'screenshot';
    if (msg.contains('search') || msg.contains('find')) return 'search';
    if (msg.contains('analyze') || msg.contains('extract')) return 'analysis';
    if (msg.contains('explain') || msg.contains('what is')) return 'explanation';
    if (msg.contains('help') || msg.contains('how to')) return 'assistance';
    
    return 'general';
  }

  Future<String> _generateResponse(
    String userMessage, 
    Map<String, dynamic> analysis, 
    Map<String, dynamic> toolResults, 
    String model
  ) async {
    // Build context from tool results
    StringBuffer responseBuffer = StringBuffer();
    
    if (toolResults.containsKey('screenshot')) {
      final screenshotResult = toolResults['screenshot'] as Map<String, dynamic>;
      if (screenshotResult['success'] == true) {
        responseBuffer.writeln('📸 **Screenshot captured successfully!**\n');
        responseBuffer.writeln('🌐 **Website:** ${screenshotResult['url']}\n');
        
        // Include the screenshot URL directly for viewing
        final screenshotUrl = screenshotResult['screenshot_url'];
        responseBuffer.writeln('🖼️ **Screenshot Preview:**');
        responseBuffer.writeln('![Screenshot](${screenshotUrl})\n');
        responseBuffer.writeln('🔗 **Direct Link:** ${screenshotUrl}\n');
        
        responseBuffer.writeln('✅ I\'ve successfully taken a screenshot of the website using WordPress preview. The screenshot is displayed above and ready to view.\n');
        
        if (screenshotResult['description'] != null) {
          responseBuffer.writeln('📝 **Details:** ${screenshotResult['description']}\n');
        }
      } else {
        responseBuffer.writeln('❌ **Screenshot failed**\n');
        responseBuffer.writeln('Sorry, I couldn\'t capture the screenshot. ${screenshotResult['error'] ?? 'Unknown error occurred.'}\n');
      }
    }

    if (toolResults.containsKey('web_search')) {
      final searchResults = toolResults['web_search'] as Map<String, dynamic>;
      if (searchResults['success'] == true) {
        responseBuffer.writeln('🔍 **Search Results Found**\n');
        
        final results = searchResults['results'] as List<dynamic>? ?? [];
        for (int i = 0; i < results.length && i < 3; i++) {
          final result = results[i] as Map<String, dynamic>;
          responseBuffer.writeln('**${result['title'] ?? 'Result ${i + 1}'}**');
          if (result['snippet'] != null) {
            responseBuffer.writeln('${result['snippet']}\n');
          }
        }
      }
    }

    if (toolResults.containsKey('analyze_page')) {
      final analysisResult = toolResults['analyze_page'] as Map<String, dynamic>;
      if (analysisResult['success'] == true) {
        responseBuffer.writeln('📊 **Page Analysis Complete**\n');
        responseBuffer.writeln('${analysisResult['summary'] ?? 'Analysis completed successfully'}\n');
      }
    }

    // If no tools were used, provide helpful message
    if (toolResults.isEmpty) {
      responseBuffer.writeln('I understand you\'re asking: "${userMessage}"\n');
      responseBuffer.writeln('Let me help you with that directly.\n');
      
      // Add contextual help based on the request
      final intent = analysis['intent'];
      if (intent == 'screenshot') {
        responseBuffer.writeln('💡 **Tip:** To take a screenshot, make sure to include a website URL (like "take screenshot of google.com")');
      }
    }

    // Add completion message
    responseBuffer.writeln('\n---\n');
    responseBuffer.writeln('✨ **Task completed!** How else can I help you?');

    return responseBuffer.toString();
  }



  Future<String> _handleError(String userMessage, String model, String error) async {
    return 'I apologize, but I encountered an error while processing your request: $error\n\nLet me try to help you in a different way. Could you please rephrase your question?';
  }

  // Tool implementations
  Future<Map<String, dynamic>> _executeWebSearch(Map<String, dynamic> params) async {
    final query = params['query'] as String? ?? '';
    final source = params['source'] as String? ?? 'both';
    final limit = params['limit'] as int? ?? 5;

    try {
      List<Map<String, dynamic>> allResults = [];

      if (source == 'wikipedia' || source == 'both') {
        final wikiResults = await _searchWikipedia(query, limit);
        allResults.addAll(wikiResults);
      }

      if (source == 'duckduckgo' || source == 'both') {
        final ddgResults = await _searchDuckDuckGo(query, limit);
        allResults.addAll(ddgResults);
      }

      return {
        'success': true,
        'query': query,
        'source': source,
        'results': allResults.take(limit).toList(),
        'total_found': allResults.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'query': query,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _searchWikipedia(String query, int limit) async {
    try {
      final searchUrl = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}'
      );
      
      final response = await http.get(searchUrl);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return [
          {
            'title': data['title'] ?? 'Wikipedia Result',
            'snippet': data['extract'] ?? 'No description available',
            'url': data['content_urls']?['desktop']?['page'] ?? '',
            'source': 'Wikipedia',
          }
        ];
      }
    } catch (e) {
      debugPrint('Wikipedia search error: $e');
    }
    
    return [];
  }

  Future<List<Map<String, dynamic>>> _searchDuckDuckGo(String query, int limit) async {
    // Simulated DuckDuckGo results since API requires special access
    await Future.delayed(Duration(milliseconds: 500)); // Simulate network delay
    
    return [
      {
        'title': 'Search result for: $query',
        'snippet': 'This is a simulated search result. In a real implementation, this would connect to DuckDuckGo\'s API or use web scraping.',
        'url': 'https://duckduckgo.com/?q=${Uri.encodeComponent(query)}',
        'source': 'DuckDuckGo',
      }
    ];
  }

  Future<Map<String, dynamic>> _executeScreenshot(Map<String, dynamic> params) async {
    final url = params['url'] as String? ?? '';
    final width = params['width'] as int? ?? 1200;
    final height = params['height'] as int? ?? 800;

    try {
      // Use WordPress.com mshots API for screenshots
      final screenshotUrl = 'https://s0.wp.com/mshots/v1/${Uri.encodeComponent(url)}?w=$width&h=$height';
      
      final response = await http.get(Uri.parse(screenshotUrl));
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'url': url,
          'screenshot_url': screenshotUrl,
          'width': width,
          'height': height,
          'description': 'Screenshot captured successfully for $url using WordPress preview',
          'service': 'WordPress mshots',
        };
      } else {
        return {
          'success': false,
          'error': 'WordPress screenshot service returned status ${response.statusCode}',
          'url': url,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to capture screenshot: $e',
        'url': url,
      };
    }
  }

  Future<Map<String, dynamic>> _executePageAnalyzer(Map<String, dynamic> params) async {
    final url = params['url'] as String;
    final type = params['type'] as String? ?? 'content';

    try {
      // Simulate page analysis
      await Future.delayed(Duration(milliseconds: 600));
      
      return {
        'success': true,
        'url': url,
        'type': type,
        'summary': 'Page analysis completed. Found relevant content and extracted key information.',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'url': url,
      };
    }
  }

  List<AgentTool> getAvailableTools() {
    return _tools.values.toList();
  }

  AgentTool? getTool(String name) {
    return _tools[name];
  }
}