import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/code_execution_service.dart';

class CodeExecutionDialog extends StatefulWidget {
  final String code;
  final String language;

  const CodeExecutionDialog({
    super.key,
    required this.code,
    required this.language,
  });

  @override
  State<CodeExecutionDialog> createState() => _CodeExecutionDialogState();
}

class _CodeExecutionDialogState extends State<CodeExecutionDialog> {
  bool _isExecuting = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _executeCode();
  }

  Future<void> _executeCode() async {
    setState(() {
      _isExecuting = true;
      _result = null;
    });

    final result = await CodeExecutionService.executeCode(
      code: widget.code,
      language: widget.language,
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
        _result = result;
      });
    }
  }

  void _copyOutput() {
    if (_result != null && _result!['output'] != null) {
      Clipboard.setData(ClipboardData(text: _result!['output']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Output copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final executor = CodeExecutionService.getLanguageExecutor(widget.language);
    final icon = CodeExecutionService.getExecutionIcon(widget.language);

    return Dialog(
      backgroundColor: const Color(0xFFF4F3F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEAE9E5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code Execution',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                        Text(
                          'Running with $executor',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF666666),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _isExecuting
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF000000),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Executing code...',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _result == null
                        ? const Center(
                            child: Text(
                              'No execution result',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 16,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Execution status
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _result!['success']
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _result!['success']
                                          ? Colors.green
                                          : Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _result!['success']
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: _result!['success']
                                            ? Colors.green
                                            : Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _result!['success']
                                            ? 'Executed successfully'
                                            : 'Execution failed',
                                        style: TextStyle(
                                          color: _result!['success']
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_result!['executionTime'] > 0) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          '(${_result!['executionTime']}ms)',
                                          style: const TextStyle(
                                            color: Color(0xFF666666),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Output section
                                if (_result!['output'] != null &&
                                    _result!['output'].toString().isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Text(
                                        'Output:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF000000),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: _copyOutput,
                                        icon: const Icon(Icons.copy),
                                        color: const Color(0xFF666666),
                                        iconSize: 20,
                                        tooltip: 'Copy output',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF000000),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _result!['output'].toString(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        color: Color(0xFF00FF00),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                                
                                // Error section
                                if (_result!['error'] != null &&
                                    _result!['error'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Error:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D1B1B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _result!['error'].toString(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        color: Color(0xFFFF6B6B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),
            ),
            
            // Footer with action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFD0CFCB),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExecuting ? null : _executeCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Run Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF000000),
                        side: const BorderSide(color: Color(0xFFD0CFCB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: const Color(0xFFFFFFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}