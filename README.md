# DublagemThief2014

Projeto de criação de uma dublagem PT-BR para Thief (2014).

## Objetivo

Identificar os arquivos de voz do jogo, gerar versões em português
brasileiro e substituir os respectivos áudios preservando a estrutura
Wwise utilizada pelo jogo.

## Fluxo

PCK / BNK
↓
QuickBMS
↓
WEM
↓
Wwiser
↓
XML / HIRC
↓
Event → Action → Sound → WEM
↓
Identificação das falas
↓
Voz PT-BR
↓
Substituição
↓
Teste no jogo

## Estrutura

- Docs: documentação
- Scripts: scripts utilizados no projeto
- Analysis: análises dos arquivos
- AudioMap: relação entre eventos e áudios
- Voice: arquivos relacionados às vozes
- Tools: documentação das ferramentas
- Tests: testes realizados

## Laboratório

Os arquivos pesados do jogo permanecem fora deste repositório:

B:\Thief2014_Dubbing\

Arquivos PCK, BNK, WEM e ferramentas pesadas não são versionados.

## Status

Fase atual: engenharia reversa do sistema de áudio Wwise.

Primeiro pacote analisado:

th4_000_common_vo

Resultados atuais:

- 1.151 WEM extraídos
- BNK analisado pelo Wwiser
- XML gerado
- estrutura Wwise ainda sendo interpretada
