import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'admin_auth_service.dart';
import 'admin_api_manager.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  APISettings? _currentSettings;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String _connectionStatus = '';
  
  final _passwordController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAuthAndLoadSettings();
  }

  Future<void> _checkAuthAndLoadSettings() async {
    final isAuth = await AdminAuthService.isAdminAuthenticated();
    setState(() {
      _isAuthenticated = isAuth;
    });
    
    if (isAuth) {
      await _loadCurrentSettings();
    }
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    
    final settings = await AdminAPIManager.getCurrentAPISettings();
    setState(() {
      _currentSettings = settings;
      _apiKeyController.text = settings.apiKey;
      _endpointController.text = settings.endpoint;
      _isLoading = false;
    });
  }

  Future<void> _authenticate() async {
    final password = _passwordController.text;
    final success = await AdminAuthService.authenticate(password);
    
    if (success) {
      setState(() => _isAuthenticated = true);
      _passwordController.clear();
      await _loadCurrentSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Admin access granted!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Invalid admin password'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await AdminAuthService.logout();
    setState(() {
      _isAuthenticated = false;
      _currentSettings = null;
    });
    _passwordController.clear();
    _apiKeyController.clear();
    _endpointController.clear();
  }

  Future<void> _saveSettings() async {
    if (_currentSettings == null) return;
    
    setState(() => _isLoading = true);
    
    final updatedSettings = _currentSettings!.copyWith(
      apiKey: _apiKeyController.text,
      endpoint: _endpointController.text,
    );
    
    await AdminAPIManager.saveAPISettings(updatedSettings);
    setState(() {
      _currentSettings = updatedSettings;
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _testConnection() async {
    if (_currentSettings == null) return;
    
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing connection...';
    });
    
    final result = await AdminAPIManager.testConnection(_currentSettings!);
    
    setState(() {
      _isLoading = false;
      _connectionStatus = result['success'] 
          ? '✅ ${result['message']} (${result['responseTime']})'
          : '❌ ${result['error']}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: _isAuthenticated
            ? [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.rightFromBracket),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ]
            : null,
      ),
      body: _isAuthenticated ? _buildAdminPanel() : _buildLoginForm(),
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 64,
              color: Colors.black,
            ),
            const SizedBox(height: 24),
            const Text(
              'Admin Access Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter admin password to access the control panel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onSubmitted: (_) => _authenticate(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Access Admin Panel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Default password: ahamai_admin_2024',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminPanel() {
    return Column(
      children: [
        // Admin Info Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Admin Mode Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Spacer(),
              FutureBuilder<Map<String, dynamic>>(
                future: AdminAuthService.getAdminInfo(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final info = snapshot.data!;
                    final hours = info['sessionRemainingHours'] as double;
                    return Text(
                      'Session: ${hours.toStringAsFixed(1)}h remaining',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
        
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: const [
              Tab(icon: Icon(Icons.api), text: 'API Config'),
              Tab(icon: Icon(Icons.psychology), text: 'Models'),
              Tab(icon: Icon(Icons.settings), text: 'Advanced'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAPIConfigTab(),
              _buildModelsTab(),
              _buildAdvancedTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAPIConfigTab() {
    if (_currentSettings == null || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Current Configuration',
            [
              _buildInfoRow('Provider', _currentSettings!.provider.displayName),
              _buildInfoRow('Model', _currentSettings!.model.displayName),
              _buildInfoRow('Status', _currentSettings!.isActive ? 'Active' : 'Inactive'),
              _buildInfoRow('Last Updated', _formatDateTime(_currentSettings!.lastUpdated)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildSectionCard(
            'API Settings',
            [
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: 'API Endpoint',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          if (_connectionStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _connectionStatus.contains('✅') 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _connectionStatus.contains('✅') 
                      ? Colors.green 
                      : Colors.red,
                ),
              ),
              child: Text(
                _connectionStatus,
                style: TextStyle(
                  color: _connectionStatus.contains('✅') 
                      ? Colors.green 
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelsTab() {
    if (_currentSettings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            'AI Model Selection',
            [
              const Text(
                'Choose the AI model for your application:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...AIModel.values.map((model) => _buildModelTile(model)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildSectionCard(
            'Quick Presets',
            [
              const Text(
                'Switch to pre-configured setups:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...AdminAPIManager.getQuickPresets().map((preset) => 
                _buildPresetTile(preset)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return const Center(
      child: Text('Advanced settings coming soon...'),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<APISettings>>(
      future: AdminAPIManager.getConfigHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Center(
            child: Text('No configuration history available'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final config = history[index];
            return _buildHistoryTile(config, index);
          },
        );
      },
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelTile(AIModel model) {
    final isSelected = _currentSettings?.model == model;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(model.displayName),
        subtitle: Text(model.modelId),
        leading: Radio<AIModel>(
          value: model,
          groupValue: _currentSettings?.model,
          onChanged: (value) async {
            if (value != null) {
              final updatedSettings = _currentSettings!.copyWith(model: value);
              await AdminAPIManager.saveAPISettings(updatedSettings);
              setState(() => _currentSettings = updatedSettings);
            }
          },
        ),
        tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetTile(APISettings preset) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${preset.provider.displayName} - ${preset.model.displayName}'),
        subtitle: Text(preset.endpoint),
        trailing: ElevatedButton(
          onPressed: () async {
            await AdminAPIManager.saveAPISettings(preset);
            await _loadCurrentSettings();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to ${preset.model.displayName}'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: const Text('Apply'),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(APISettings config, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${config.provider.displayName} - ${config.model.displayName}'),
        subtitle: Text(_formatDateTime(config.lastUpdated)),
        trailing: IconButton(
          icon: const Icon(Icons.restore),
          onPressed: () async {
            await AdminAPIManager.saveAPISettings(config);
            await _loadCurrentSettings();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Configuration restored'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    _endpointController.dispose();
    super.dispose();
  }
}