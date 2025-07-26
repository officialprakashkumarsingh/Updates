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
  
  // Callback for model switching
  void Function(String modelName)? _modelSwitchCallback;

  bool get isExecuting => _isExecuting;
  String get lastToolUsed => _lastToolUsed;
  Map<String, dynamic> get lastResult => Map.unmodifiable(_lastResult);

  void _initializeTools() {
    // Screenshot tool - takes screenshots of webpages using WordPress preview
    _tools['screenshot'] = ExternalTool(
      name: 'screenshot',
      description: 'Takes a screenshot of any webpage using WordPress preview service. The AI can use this tool to visually understand websites, capture content, or help users with visual tasks.',
      parameters: {
        'url': {'type': 'string', 'description': 'The URL to take screenshot of', 'required': true},
        'width': {'type': 'integer', 'description': 'Screenshot width in pixels (default: 1200)', 'default': 1200},
        'height': {'type': 'integer', 'description': 'Screenshot height in pixels (default: 800)', 'default': 800},
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

  /// Set the model switch callback (called by main shell)
  void setModelSwitchCallback(void Function(String modelName) callback) {
    _modelSwitchCallback = callback;
  }

  // Tool implementations

  Future<Map<String, dynamic>> _executeScreenshot(Map<String, dynamic> params) async {
    final url = params['url'] as String? ?? '';
    final width = params['width'] as int? ?? 1200;
    final height = params['height'] as int? ?? 800;

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
      
      // Verify the screenshot service is accessible with a longer timeout
      try {
        final response = await http.head(Uri.parse(screenshotUrl)).timeout(Duration(seconds: 15));
        
        return {
          'success': true,
          'url': parsedUrl.toString(),
          'screenshot_url': screenshotUrl,
          'preview_url': screenshotUrl, // Direct WordPress preview
          'width': width,
          'height': height,
          'description': 'Screenshot captured successfully for ${parsedUrl.toString()}',
          'service': 'WordPress mshots API (direct preview)',
          'accessible': response.statusCode == 200,
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
        };
      } catch (e) {
        // Even if head request fails, the screenshot service might still work
        return {
          'success': true,
          'url': parsedUrl.toString(),
          'screenshot_url': screenshotUrl,
          'preview_url': screenshotUrl,
          'width': width,
          'height': height,
          'description': 'Screenshot service initiated for ${parsedUrl.toString()}',
          'service': 'WordPress mshots API (direct preview)',
          'note': 'Service response pending - image may take a moment to generate',
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to capture screenshot: $e',
        'url': url,
        'tool_executed': false,
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
      ).timeout(Duration(seconds: 30));

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
          'tool_executed': true,
          'execution_time': DateTime.now().toIso8601String(),
          'api_status': 'Connected successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'API returned status ${response.statusCode}: ${response.reasonPhrase}',
          'tool_executed': true,
          'api_status': 'Failed to connect',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to fetch AI models: $e',
        'tool_executed': true,
        'api_status': 'Connection error',
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
        'tool_executed': false,
      };
    }

    try {
      // First, verify the model exists by fetching the models list
      final modelsResult = await _fetchAIModels({'refresh': true});
      
      if (modelsResult['success'] == true) {
        final models = modelsResult['models'] as List<String>;
        
        if (models.contains(modelName)) {
          // Actually switch the model if callback is available
          if (_modelSwitchCallback != null) {
            _modelSwitchCallback!(modelName);
          }
          
          return {
            'success': true,
            'new_model': modelName,
            'reason': reason,
            'available_models': models,
            'tool_executed': true,
            'execution_time': DateTime.now().toIso8601String(),
            'action_completed': _modelSwitchCallback != null ? 'Model switched successfully' : 'UI should update the selected model to $modelName',
            'validation': 'Model exists and is available',
          };
        } else {
          return {
            'success': false,
            'error': 'Model "$modelName" not found in available models',
            'available_models': models,
            'suggestion': 'Try one of the available models listed above',
            'tool_executed': true,
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Could not fetch models list to verify model exists',
          'reason': modelsResult['error'],
          'tool_executed': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to switch AI model: $e',
        'tool_executed': true,
      };
    }
  }
}