# VS Executor 🎵

Um mixer de áudio multi-track em tempo real construído com Flutter, baseado em SoLoud. Permite carregar múltiplas faixas de áudio, sincronizar BPM automaticamente e visualizar a intensidade do áudio dinamicamente.

## 📋 Características

✨ **Mixer Multi-Track**
- Suporte para até 16 faixas de áudio simultâneas
- Controle individual de volume, pan e mute/solo
- Roteamento A/B para processamento separado

🎵 **Auto-detecção de BPM**
- Detecta automaticamente BPM de arquivos com "Click" no nome
- Reconhece padrões como "120 BPM", "[120]", "120-bpm", etc.
- Sincroniza o BPM do app com a faixa detectada

📊 **Visualização Avançada**
- VU Meter em tempo real com seguimento de picos
- Visualizador de intensidade com 12-16 barras animadas
- Feedback visual dinâmico da intensidade do áudio

🔌 **Recursos Profissionais**
- Metrônomo com cliques de beat
- Marcadores de seção (Intro, Verso, Refrão, etc.)
- Assinatura de tempo personalizável
- Controle de BPM em tempo real
- Roteamento de áudio com controles de volume separados

💾 **Gerenciamento de Projetos**
- Salvar/carregar projetos completos
- Histórico de projetos recentes
- Exportação de configurações de projeto

## 🚀 Início Rápido

### Pré-requisitos

- Flutter SDK `^3.11.4`
- Dart `^3.11.4`
- macOS 10.11+ (para desenvolvimento em desktop)

### Instalação

```bash
# Clone o repositório
git clone <seu-repositório>
cd VS\ Executor

# Obtenha as dependências
flutter pub get

# Analise para verificar erros
flutter analyze

# Execute os testes
flutter test

# Inicie o app
flutter run -d macos
```

## 📦 Dependências Principais

```yaml
flutter_soloud: ^3.5.4      # Engine de áudio
file_picker: ^10.3.10        # Seleção de arquivos
google_fonts: ^8.0.2         # Fontes customizadas
path_provider: ^2.1.5        # Acesso ao sistema de arquivos
uuid: ^4.5.3                 # Geração de IDs únicos
equatable: ^2.0.8            # Igualdade de objetos
```

## 🏗️ Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada
├── app.dart                  # Configuração do app
├── core/
│   ├── audio/
│   │   └── audio_engine.dart # Engine de áudio central
│   ├── models/
│   │   ├── track_model.dart  # Modelo de faixa
│   │   ├── session_marker.dart
│   │   └── time_signature.dart
│   ├── services/
│   │   └── project_service.dart # Gerenciamento de projetos
│   └── utils/
│       ├── bpm_detector.dart # Detecção automática de BPM
│       ├── constants.dart
│       └── audio_utils.dart
└── ui/
    ├── screens/
    │   └── mixer_screen.dart # Tela principal
    ├── widgets/
    │   ├── mixer/
    │   │   ├── channel_strip.dart
    │   │   ├── vu_meter.dart
    │   │   ├── intensity_visualizer.dart
    │   │   └── ...
    │   ├── transport/
    │   │   ├── transport_bar.dart
    │   │   └── bpm_control.dart
    │   └── notifications/
    │       └── bpm_detection_notifier.dart
    └── theme/
        └── app_colors.dart
```

## 🎮 Como Usar

### 1. **Adicionar Faixas**

```bash
# Clique em "+" na interface
# Selecione arquivos de áudio (.mp3, .wav, .flac, etc.)
# O app detectará automaticamente o BPM se houver "Click" no nome
```

### 2. **Sincronizar BPM**

```
Nome do arquivo: "Click_120_BPM.wav"
↓
App detecta automaticamente BPM = 120
↓
Notificação mostra: "BPM Auto-detectado: 120"
```

### 3. **Controlar o Mixer**

- **Volume**: Arraste o fader vertical
- **Pan**: Gire o knob
- **Mute/Solo**: Clique nos botões M e S
- **Roteamento**: Togglee entre A e B

### 4. **Salvar Projeto**

```bash
# Clique em "Salvar" para persistir:
# - Todas as faixas carregadas
# - Posições, volumes, pan settings
# - BPM e assinatura de tempo
# - Marcadores de seção
```

## 🧪 Testes

```bash
# Execute todos os testes
flutter test

# Execute testes em um arquivo específico
flutter test test/core/audio/audio_engine_test.dart

# Execute testes com cobertura
flutter test --coverage

# Visualize relatório de cobertura
genhtml coverage/lcov.report -o coverage/html
open coverage/html/index.html
```

## ✅ Verificação de Qualidade

```bash
# Análise estática
flutter analyze

# Formatação de código
dart format lib/ test/

# Lint rigoroso
dart analyze --fatal-infos

# Verificar dependências desatualizadas
flutter pub outdated
```

## 📝 Comandos Frequentes

| Comando | Descrição |
|---------|-----------|
| `flutter run -d macos` | Inicia o app no macOS |
| `flutter run -d web` | Inicia no navegador (se suportado) |
| `flutter analyze` | Verifica erros de código |
| `flutter pub get` | Baixa/atualiza dependências |
| `flutter pub upgrade` | Atualiza para versões mais novas |
| `flutter clean` | Limpa build cache |
| `flutter build macos` | Build de release para macOS |

## 🎯 Features Implementadas

- ✅ Mixer multi-track com até 16 faixas
- ✅ Auto-detecção de BPM
- ✅ VU Meter com picos
- ✅ Visualizador de intensidade animado
- ✅ Metrônomo com cliques
- ✅ Marcadores de seção
- ✅ Roteamento A/B
- ✅ Gestão de projetos com histórico
- ✅ Interface modular e responsiva

## 🔄 Detecção de BPM - Détalhes Técnicos

O sistema reconhece os seguintes padrões em nomes de arquivo:

```
✓ "Click_120_BPM.wav"      → 120 BPM
✓ "[120] Click Track.wav"   → 120 BPM  
✓ "120-bpm click.wav"       → 120 BPM
✓ "click_140.wav"           → 140 BPM
✓ "140Hz click tone.wav"    → 140 BPM
```

**Como funciona:**

1. Arquivo é adicionado via FilePicker
2. `BpmDetector` verifica se contém "Click"
3. Se sim, extrai número usando regex
4. Valida BPM (40-300 alcance válido)
5. Atualiza BPM do app automaticamente
6. Mostra notificação com opções de ajuste

## 🐛 Resolução de Problemas

### Erro: "Failed to foreground app"
- Feche any instâncias anteriores do app
- Execute `flutter clean && flutter pub get`
- Reinicie o simulador/device

### Áudio não toca
- Verifique permissões de áudio
- Teste com um arquivo .wav simples
- Verifique se o arquivo está em formato suportado

### BPM não detecta
- Confirme que o arquivo tem "Click" no nome (case-insensitive)
- Verifique se o número está no intervalo 40-300
- Teste com padrão "120 BPM" no nome

## 📚 Referências

- [Flutter Documentation](https://flutter.dev/docs)
- [SoLoud Audio Engine](https://sol.gfxile.net/soloud/)
- [Dart Language](https://dart.dev/)

## 🤝 Contribuição

1. Faça fork do projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo LICENSE para detalhes.

## 👨‍💻 Autor

Desenvolvido com ❤️ usando Flutter & Dart

---

**Última atualização:** Abril 2026
**Versão:** 0.1.0

