  Widget _buildHeader(bool isWide) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Project Actions (Left) - Scrollable if tight
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderButton(
                    icon: Icons.note_add_rounded,
                    label: 'Novo',
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Novo Projeto?'),
                          content: const Text('Isso irá limpar o projeto atual. Deseja continuar?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Limpar Tudo', style: TextStyle(color: AppColors.muteRed)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await engine.resetProject();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Novo projeto criado!'),
                              backgroundColor: AppColors.playGreen,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    icon: Icons.save_rounded,
                    label: 'Salvar',
                    onTap: () async {
                      String? projectName;
                      if (Theme.of(context).platform == TargetPlatform.android || 
                          Theme.of(context).platform == TargetPlatform.iOS) {
                        projectName = await _showSaveProjectDialog(context);
                        if (projectName == null || projectName.trim().isEmpty) return;
                        if (!projectName.endsWith('.vsexec')) projectName += '.vsexec';
                      }

                      final success = await ProjectService.saveProject(engine, fileName: projectName);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Projeto salvo!' : 'Erro ao salvar'),
                            backgroundColor: success ? AppColors.playGreen : AppColors.muteRed,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    icon: Icons.folder_open_rounded,
                    label: 'Abrir',
                    onTap: () async {
                      setState(() => _isLoading = true);
                      final success = await ProjectService.loadProject(engine);
                      setState(() => _isLoading = false);
                      if (mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Projeto carregado!'),
                            backgroundColor: AppColors.playGreen,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    key: _recentButtonKey,
                    icon: Icons.history_rounded,
                    label: 'Recentes',
                    onTap: () => _showRecentProjectsMenu(context, _recentButtonKey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Centralized Audio Options
          Flexible(
            flex: 3,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BpmControl(engine: engine),
                    const SizedBox(width: 8),
                    TimeSignatureSelector(engine: engine),
                    if (isWide) ...[
                      const SizedBox(width: 12),
                      Container(width: 1, height: 28, color: AppColors.border),
                      const SizedBox(width: 12),
                      // Audio Devices Button
                      Tooltip(
                        message: 'Gerenciar Dispositivos de Áudio',
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/audio-devices'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speaker_phone_rounded, size: 16, color: AppColors.accent),
                                const SizedBox(width: 6),
                                const Text(
                                  'Áudio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Logo / Title (Right) - Hide if narrow
          if (isWide || MediaQuery.of(context).size.width > 400)
            Flexible(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'VS EXECUTOR',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
