import 'external_tools_service.dart';

void main() async {
  print('🔧 External Tools Service Test');
  print('================================\n');
  
  final toolsService = ExternalToolsService();
  
  // Test 1: List available tools
  print('📋 Available Tools:');
  final tools = toolsService.getAvailableTools();
  for (var tool in tools) {
    print('  • ${tool.name}: ${tool.description}');
  }
  print('');
  
  // Test 2: Test screenshot tool
  print('📸 Testing Screenshot Tool:');
  try {
    final screenshotResult = await toolsService.executeTool('screenshot', {
      'url': 'https://www.google.com',
      'width': 800,
      'height': 600
    });
    
    if (screenshotResult['success'] == true) {
      print('  ✅ Screenshot successful!');
      print('  📷 URL: ${screenshotResult['screenshot_url']}');
      print('  🌐 Target: ${screenshotResult['url']}');
    } else {
      print('  ❌ Screenshot failed: ${screenshotResult['error']}');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
  print('');
  
  // Test 3: Test AI models fetcher
  print('🤖 Testing AI Models Fetcher:');
  try {
    final modelsResult = await toolsService.executeTool('fetch_ai_models', {
      'refresh': true
    });
    
    if (modelsResult['success'] == true) {
      print('  ✅ Models fetched successfully!');
      final models = modelsResult['models'] as List<String>;
      print('  📊 Found ${models.length} models:');
      for (int i = 0; i < models.length && i < 5; i++) {
        print('    ${i + 1}. ${models[i]}');
      }
      if (models.length > 5) {
        print('    ... and ${models.length - 5} more');
      }
    } else {
      print('  ❌ Models fetch failed: ${modelsResult['error']}');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
  print('');
  
  // Test 4: Test model switcher
  print('🔄 Testing Model Switcher:');
  try {
    final switchResult = await toolsService.executeTool('switch_ai_model', {
      'model_name': 'claude-3-7-sonnet',
      'reason': 'Testing external tools'
    });
    
    if (switchResult['success'] == true) {
      print('  ✅ Model switch prepared!');
      print('  🎯 Target model: ${switchResult['new_model']}');
      print('  📝 Reason: ${switchResult['reason']}');
      print('  ⚠️  Action required: ${switchResult['action_required']}');
    } else {
      print('  ❌ Model switch failed: ${switchResult['error']}');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
  print('');
  
  // Test 5: Test web search
  print('🔍 Testing Web Search:');
  try {
    final searchResult = await toolsService.executeTool('web_search', {
      'query': 'artificial intelligence news',
      'limit': 3
    });
    
    if (searchResult['success'] == true) {
      print('  ✅ Web search successful!');
      final results = searchResult['results'] as List<dynamic>;
      print('  📰 Found ${results.length} results:');
      for (int i = 0; i < results.length; i++) {
        final result = results[i] as Map<String, dynamic>;
        print('    ${i + 1}. ${result['title']} (${result['source']})');
      }
    } else {
      print('  ❌ Web search failed: ${searchResult['error']}');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
  print('');
  
  // Test 6: Test capabilities check
  print('⚙️  Tool Capabilities:');
  print('  📸 Screenshot capability: ${toolsService.hasScreenshotCapability}');
  print('  🤖 Model switching capability: ${toolsService.hasModelSwitchingCapability}');
  print('  📊 Last tool used: ${toolsService.lastToolUsed}');
  print('  🔄 Currently executing: ${toolsService.isExecuting}');
  
  print('\n🎉 External Tools Test Complete!');
  print('💡 The AI is now aware of these tools and can mention them to users.');
}