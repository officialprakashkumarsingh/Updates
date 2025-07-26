import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'agent_service.dart';

class AgentStatusWidget extends StatefulWidget {
  final AgentService agentService;

  const AgentStatusWidget({
    super.key,
    required this.agentService,
  });

  @override
  State<AgentStatusWidget> createState() => _AgentStatusWidgetState();
}

class _AgentStatusWidgetState extends State<AgentStatusWidget> {
  @override
  void initState() {
    super.initState();
    widget.agentService.addListener(_onAgentServiceChanged);
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    super.dispose();
  }

  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clean status widget - no more banner
    return const SizedBox.shrink();
  }
}

// Clean and simple agent processing indicator
class AgentProcessingPanel extends StatefulWidget {
  final AgentService agentService;
  final Map<String, dynamic> processingResults;

  const AgentProcessingPanel({
    super.key,
    required this.agentService,
    required this.processingResults,
  });

  @override
  State<AgentProcessingPanel> createState() => _AgentProcessingPanelState();
}

class _AgentProcessingPanelState extends State<AgentProcessingPanel> 
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    widget.agentService.addListener(_onAgentServiceChanged);
    
    _fadeController.forward();
    
    if (widget.agentService.isProcessing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});
      
      if (widget.agentService.isProcessing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show if processing or has results
    if (!widget.agentService.isProcessing && 
        widget.processingResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFF8FAFC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.agentService.isProcessing 
                ? const Color(0xFF6366F1).withOpacity(0.3)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.agentService.isProcessing 
                  ? const Color(0xFF6366F1).withOpacity(0.1)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Clean animated indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.agentService.isProcessing 
                        ? 1.0 + (_pulseAnimation.value * 0.15)
                        : 1.0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.agentService.isProcessing 
                            ? const Color(0xFF6366F1).withOpacity(0.1)
                            : const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.agentService.isProcessing 
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF10B981),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: widget.agentService.isProcessing
                            ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFF6366F1),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: const Color(0xFF10B981),
                              ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status text
                    Text(
                      widget.agentService.isProcessing 
                          ? (widget.agentService.status.isNotEmpty 
                              ? widget.agentService.status 
                              : 'Agent is processing...')
                          : 'Agent analysis complete',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.agentService.isProcessing 
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF10B981),
                      ),
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Processing info
                    if (widget.agentService.isProcessing) ...[
                      Text(
                        'Running intelligent analysis',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ] else if (widget.processingResults.isNotEmpty) ...[
                      Text(
                        _getResultSummary(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getResultSummary() {
    final results = widget.processingResults;
    
    if (results['tools_executed'] != null) {
      final tools = results['tools_executed'] as List<dynamic>;
      if (tools.isNotEmpty) {
        return 'Used ${tools.length} tool${tools.length > 1 ? 's' : ''}: ${tools.join(', ')}';
      }
    }
    
    if (results['analysis'] != null) {
      return 'Analysis completed successfully';
    }
    
    return 'Processing completed';
  }
}