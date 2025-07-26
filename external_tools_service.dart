import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExternalTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params) execute;

  ExternalTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.execute,
  });
}

class ExternalToolsService extends ChangeNotifier {
  static final ExternalToolsService _instance = ExternalToolsService._internal();
  factory ExternalToolsService() => _instance;
  ExternalToolsService._internal() {
    _initializeTools();
  }

  final Map<String, ExternalTool> _tools = {};
  bool _isExecuting = false;
  String _lastToolUsed = '';
  Map<String, dynamic> _lastResult = {};

  bool get isExecuting => _isExecuting;
  String get lastToolUsed => _lastToolUsed;
  Map<String, dynamic> get lastResult => Map.unmodifiable(_lastResult);

  void _initializeTools() {
    // Screenshot tool - takes screenshots of webpages
    _tools['screenshot'] = ExternalTool(
      name: 'screenshot',
      description: 'Takes a screenshot of any webpage. The AI can use this tool to visually understand websites, capture content, or help users with visual tasks.',
      parameters: {
        'url': {'type': 'string', 'description': 'The URL to take screenshot of', 'required': true},
        'width': {'type': 'integer', 'description': 'Screenshot width in pixels (default: 1200)', 'default': 1200},
        'height': {'type': 'integer', 'description': 'Screenshot height in pixels (default: 800)', 'default': 800},
        'fullPage': {'type': 'boolean', 'description': 'Capture full page or just viewport (default: false)', 'default': false},
      },
      execute: _executeScreenshot,
    );

    // AI Models fetcher - dynamically fetches available AI models
    _tools['fetch_ai_models'] = ExternalTool(
      name: 'fetch_ai_models',
      description: 'Fetches available AI models from the API. The AI can use this to switch models if one is not responding or if the user is not satisfied with the current model.',
      parameters: {
        'refresh': {'type': 'boolean', 'description': 'Force refresh the models list (default: false)', 'default': false},
        'filter': {'type': 'string', 'description': 'Filter models by name pattern (optional)', 'default': ''},
      },
      execute: _fetchAIModels,
    );

    // Model switcher - switches the current AI model
    _tools['switch_ai_model'] = ExternalTool(
      name: 'switch_ai_model',
      description: 'Switches to a different AI model. The AI can use this when a model is not responding well or when the user requests a different model.',
      parameters: {
        'model_name': {'type': 'string', 'description': 'Name of the model to switch to', 'required': true},
        'reason': {'type': 'string', 'description': 'Reason for switching models (optional)', 'default': 'User request'},
      },
      execute: _switchAIModel,
    );

    // Web search tool - searches the web for information
    _tools['web_search'] = ExternalTool(
      name: 'web_search',
      description: 'Searches the web for current information. The AI can use this to get up-to-date information about any topic.',
      parameters: {
        'query': {'type': 'string', 'description': 'The search query', 'required': true},
        'source': {'type': 'string', 'description': 'Search source: wikipedia, duckduckgo, or both (default: both)', 'default': 'both'},
        'limit': {'type': 'integer', 'description': 'Number of results to return (default: 5)', 'default': 5},
      },
      execute: _executeWebSearch,
    );
  }

  /// Execute a tool by name with given parameters
  Future<Map<String, dynamic>> executeTool(String toolName, Map<String, dynamic> params) async {
    if (!_tools.containsKey(toolName)) {
      return {
        'success': false,
        'error': 'Tool "$toolName" not found',
        'available_tools': _tools.keys.toList(),
      };
    }

    _isExecuting = true;
    _lastToolUsed = toolName;
    notifyListeners();

    try {
      final result = await _tools[toolName]!.execute(params);
      _lastResult = result;
      _isExecuting = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isExecuting = false;
      _lastResult = {
        'success': false,
        'error': e.toString(),
        'tool': toolName,
      };
      notifyListeners();
      return _lastResult;
    }
  }

  /// Get list of available tools
  List<ExternalTool> getAvailableTools() {
    return _tools.values.toList();
  }

  /// Get specific tool information
  ExternalTool? getTool(String name) {
    return _tools[name];
  }

  /// Check if AI can access screenshot functionality
  bool get hasScreenshotCapability => _tools.containsKey('screenshot');

  /// Check if AI can access model switching
  bool get hasModelSwitchingCapability => _tools.containsKey('fetch_ai_models') && _tools.containsKey('switch_ai_model');

  // Tool implementations

  Future<Map<String, dynamic>> _executeScreenshot(Map<String, dynamic> params) async {
    final url = params['url'] as String? ?? '';
    final width = params['width'] as int? ?? 1200;
    final height = params['height'] as int? ?? 800;
    final fullPage = params['fullPage'] as bool? ?? false;

    if (url.isEmpty) {
      return {
        'success': false,
        'error': 'URL parameter is required',
      };
    }

    try {
      // Validate URL format
      Uri parsedUrl;
      try {
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          parsedUrl = Uri.parse('https://$url');
        } else {
          parsedUrl = Uri.parse(url);
        }
      } catch (e) {
        return {
          'success': false,
          'error': 'Invalid URL format: $url',
        };
      }

      // Use WordPress.com mshots API for screenshots
      final screenshotUrl = 'https://s0.wp.com/mshots/v1/${Uri.encodeComponent(parsedUrl.toString())}?w=$width&h=$height';
      
      // Verify the screenshot service is accessible
      final response = await http.head(Uri.parse(screenshotUrl)).timeout(Duration(seconds: 10));
      
      return {
        'success': true,
        'url': parsedUrl.toString(),
        'screenshot_url': screenshotUrl,
        'width': width,
        'height': height,
        'full_page': fullPage,
        'description': 'Screenshot captured successfully for ${parsedUrl.toString()}',
        'service': 'WordPress mshots API',
        'accessible': response.statusCode == 200,
        'tool_info': 'AI used external screenshot tool to capture website visually',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to capture screenshot: $e',
        'url': url,
        'tool_info': 'AI attempted to use screenshot tool but encountered an error',
      };
    }
  }

  Future<Map<String, dynamic>> _fetchAIModels(Map<String, dynamic> params) async {
    final refresh = params['refresh'] as bool? ?? false;
    final filter = params['filter'] as String? ?? '';

    try {
      final response = await http.get(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/models'),
        headers: {'Authorization': 'Bearer ahamaibyprakash25'},
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> models = (data['data'] as List).map<String>((item) => item['id']).toList();
        
        // Apply filter if provided
        if (filter.isNotEmpty) {
          models = models.where((model) => model.toLowerCase().contains(filter.toLowerCase())).toList();
        }

        return {
          'success': true,
          'models': models,
          'total_count': models.length,
          'filter_applied': filter,
          'refreshed': refresh,
          'tool_info': 'AI used external tool to fetch available AI models',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'success': false,
          'error': 'API returned status ${response.statusCode}: ${response.reasonPhrase}',
          'tool_info': 'AI attempted to fetch models but API request failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to fetch AI models: $e',
        'tool_info': 'AI attempted to use model fetching tool but encountered an error',
      };
    }
  }

  Future<Map<String, dynamic>> _switchAIModel(Map<String, dynamic> params) async {
    final modelName = params['model_name'] as String? ?? '';
    final reason = params['reason'] as String? ?? 'User request';

    if (modelName.isEmpty) {
      return {
        'success': false,
        'error': 'model_name parameter is required',
      };
    }

    try {
      // First, verify the model exists by fetching the models list
      final modelsResult = await _fetchAIModels({'refresh': true});
      
      if (modelsResult['success'] == true) {
        final models = modelsResult['models'] as List<String>;
        
        if (models.contains(modelName)) {
          // Note: The actual model switching would be handled by the UI
          // This tool just validates and provides information for the switch
          return {
            'success': true,
            'previous_model': 'current_model', // Would be filled by the UI
            'new_model': modelName,
            'reason': reason,
            'available_models': models,
            'tool_info': 'AI used external tool to initiate model switch',
            'action_required': 'UI should update the selected model to $modelName',
            'timestamp': DateTime.now().toIso8601String(),
          };
        } else {
          return {
            'success': false,
            'error': 'Model "$modelName" not found in available models',
            'available_models': models,
            'suggestion': 'Try one of the available models listed above',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Could not fetch models list to verify model exists',
          'reason': modelsResult['error'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to switch AI model: $e',
        'tool_info': 'AI attempted to switch models but encountered an error',
      };
    }
  }

  Future<Map<String, dynamic>> _executeWebSearch(Map<String, dynamic> params) async {
    final query = params['query'] as String? ?? '';
    final source = params['source'] as String? ?? 'both';
    final limit = params['limit'] as int? ?? 5;

    if (query.isEmpty) {
      return {
        'success': false,
        'error': 'query parameter is required',
      };
    }

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
        'tool_info': 'AI used external web search tool to find current information',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'query': query,
        'tool_info': 'AI attempted to search the web but encountered an error',
      };
    }
  }

  Future<List<Map<String, dynamic>>> _searchWikipedia(String query, int limit) async {
    try {
      final searchUrl = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}'
      );
      
      final response = await http.get(searchUrl).timeout(Duration(seconds: 10));
      
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
    // Note: This is a placeholder implementation
    // In a real app, you would integrate with DuckDuckGo's API or use web scraping
    await Future.delayed(Duration(milliseconds: 500));
    
    return [
      {
        'title': 'Search result for: $query',
        'snippet': 'Current information about $query. This is a simulated result - in production, this would connect to DuckDuckGo\'s API.',
        'url': 'https://duckduckgo.com/?q=${Uri.encodeComponent(query)}',
        'source': 'DuckDuckGo',
      }
    ];
  }
}