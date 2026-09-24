unit ERPV.UI.Tokens;

(*
  T68 (Lote 3) - Design tokens da UI (UX-SPEC.md Secao 3/8, ADR-011).

  ==========================================================================
  RESPONSABILIDADE DESTA UNIT
  ==========================================================================
  So constantes e funcoes triviais (sem regra de negocio, sem Vcl.Forms/
  Vcl.Controls alem do necessario para TColor/TFont/EscalarPx). Toda cor,
  fonte ou espacamento usado em qualquer .pas/.dfm NOVO do projeto vem daqui
  (ou de um form base que ja consumiu daqui) - valor solto (cor/fonte/
  tamanho hardcoded) em form ou DFM e reprovado em revisao (TASK.md Secao 1
  "UI", regra critica desde T68).

  ==========================================================================
  CONVERSAO DE COR: TColor do Delphi e BGR, nao RGB
  ==========================================================================
  A tabela de paleta do UX-SPEC.md Secao 3.1 lista cores como "#RRGGBB" (
  notacao web usual). TColor do Delphi armazena a cor como $00BBGGRR (ordem
  Blue-Green-Red). Cada constante abaixo foi convertida manualmente: para
  "#RRGGBB" o literal Delphi correspondente e $BBGGRR (bytes invertidos).
  Exemplo: UX-SPEC "#F5F7FA" (Fundo app) -> R=$F5 G=$F7 B=$FA -> TColor
  $FAF7F5. Cada constante abaixo tem um comentario com o hex original "#RRGGBB"
  do UX-SPEC ao lado, para conferencia rapida (recalcular se houver duvida).

  ==========================================================================
  CONTRASTE AA (WCAG) - justificativa (sem ferramenta automatica disponivel
  neste ambiente de automacao; valores abaixo replicam os ja calculados e
  publicados no UX-SPEC.md Secao 3.1, que e a fonte da verdade; conferir
  visualmente com um verificador de contraste ao abrir a IDE, ver roteiro na
  nota de T68 em TASK.md)
  ==========================================================================
  - Texto principal (#1F2933) sobre Superficie (#FFFFFF): UX-SPEC registra
    ~14:1 (>> AA 4,5:1 para texto normal).
  - Texto secundario (#52606D) sobre Superficie/Fundo app: UX-SPEC registra
    ~6,5:1 (>= AA 4,5:1).
  - Destaque (#1F6FB2) com texto branco (faixa de marca, botao primario):
    UX-SPEC registra ~5,3:1 (>= AA 4,5:1 texto normal; folga maior para UI
    >= 3:1).
  - Destaque hover/pressionado (#185A92) com texto branco: UX-SPEC registra
    > 7:1.
  - Selecao de linha (#DCEBFA) com texto principal mantido: UX-SPEC registra
    > 10:1.
  - Sucesso/Aviso/Erro/Info (par texto/fundo suave da tabela): UX-SPEC
    registra >= 4,5:1 para todos os quatro pares.
  - Cancelada/Inativo (texto #52606D sobre fundo #EDEFF2): UX-SPEC registra
    >= 4,5:1.
  Nenhuma cor nova foi introduzida nesta unit alem da tabela do UX-SPEC
  Secao 3.1 - todas as constantes abaixo sao transcricao 1:1 (so muda a
  ordem de bytes RGB->BGR), portanto os contrastes ja calculados no
  UX-SPEC continuam valendo. Se o usuario, ao abrir a IDE, medir um valor
  diferente com um verificador de contraste real, o achado deve ser
  registrado aqui e no UX-SPEC (nao decidido sozinho pelo Executor).
*)

interface

uses
  Winapi.Windows, System.UITypes, Vcl.Graphics, Vcl.Forms;

const
  // ------------------------------------------------------------------------
  // 3.1 Paleta (UX-SPEC.md Secao 3.1)
  // ------------------------------------------------------------------------
  clERPVFundoApp            = TColor($FAF7F5); // #F5F7FA - fundo da area de conteudo
  clERPVSuperficie          = TColor($FFFFFF); // #FFFFFF - grades, modais, cartoes
  clERPVBorda               = TColor($D9D2CB); // #CBD2D9 - grade, campos, divisorias
  clERPVBordaCampo          = TColor($B1A59A); // #9AA5B1 - borda de campo (contraste UI >= 3:1)
  clERPVTextoPrincipal      = TColor($33291F); // #1F2933 - corpo (~14:1 sobre branco)
  clERPVTextoSecundario     = TColor($6D6052); // #52606D - subtitulos/cabecalho de coluna/inativo (~6,5:1)
  clERPVDestaque            = TColor($B26F1F); // #1F6FB2 - faixa de marca, botao primario, foco, item ativo (~5,3:1 c/ branco)
  clERPVDestaqueHover       = TColor($925A18); // #185A92 - hover/pressionado do primario (> 7:1 c/ branco)
  clERPVSelecaoLinha        = TColor($FAEBDC); // #DCEBFA - linha selecionada (texto principal mantido, > 10:1)
  clERPVZebra               = TColor($FCFAF8); // #F8FAFC - linhas alternadas (sutil)
  clERPVLinhaGrade          = TColor($EBE7E4); // #E4E7EB - linha horizontal 1px do grid (nunca vertical forte)
  clERPVSucessoTexto        = TColor($3A7B1E); // #1E7B3A - Quitada, Ativo, sucesso
  clERPVSucessoFundo        = TColor($EAF4E6); // #E6F4EA
  clERPVAvisoTexto          = TColor($00538A); // #8A5300 - Pendente, Sinc, aviso
  clERPVAvisoFundo          = TColor($DBF4FF); // #FFF4DB
  clERPVErroTexto           = TColor($1E26B3); // #B3261E - erro, Cancelar venda, campo invalido (tambem usado como borda)
  clERPVErroFundo           = TColor($EAECFD); // #FDECEA
  clERPVInfoTexto           = TColor($8E5E0B); // #0B5E8E - banner informativo
  clERPVInfoFundo           = TColor($FAF1E5); // #E5F1FA
  clERPVInativoTexto        = TColor($6D6052); // #52606D - Cancelada, Inativo (mesmo valor de TextoSecundario)
  clERPVInativoFundo        = TColor($F2EFED); // #EDEFF2
  clERPVCampoDesabilitadoFundo = TColor($F2EFED); // #EDEFF2 - mesmo tom de Inativo (§3.2 "Editores")

  // ------------------------------------------------------------------------
  // 3.1 Tipografia (fonte do sistema; escala em PONTOS, escala com DPI)
  // ------------------------------------------------------------------------
  ERPVFontePrincipal    = 'Segoe UI';
  ERPVFonteFallback     = 'Tahoma';
  ERPVTamCorpo          = 9;  // corpo (12 px equivalente)
  ERPVTamRotuloCampo    = 9;  // rotulo de campo, semibold (fsBold)
  ERPVTamCabecalhoCol   = 9;  // cabecalho de coluna, semibold, cor secundaria
  ERPVTamSubtitulo      = 10; // subtitulo
  ERPVTamTituloPagina   = 14; // titulo de pagina, semibold
  ERPVTamTotalVenda     = 16; // total da venda, bold
  ERPVTamFaixaMarca     = 12; // faixa de marca, semibold

  // ------------------------------------------------------------------------
  // 3.1 Espacamento (grid de 8 px) e dimensoes fixas de layout
  // ------------------------------------------------------------------------
  ERPVEspaco4  = 4;
  ERPVEspaco8  = 8;
  ERPVEspaco16 = 16;
  ERPVEspaco24 = 24;
  ERPVMargemPagina         = 16;
  ERPVEspacoEntreCampos    = 8;
  ERPVEspacoRotuloCampo    = 4;
  ERPVEspacoEntreGrupos    = 16;
  ERPVAlturaControle       = 28; // botao e editor
  ERPVAlturaLinhaGrade     = 28;
  ERPVAlturaBarraAcoes     = 40;
  ERPVAlturaFaixaMarca     = 48;
  ERPVAlturaStatusBar      = 24;
  ERPVLarguraNavLateral    = 200;
  ERPVAlturaItemNav        = 36;

  // ------------------------------------------------------------------------
  // 3.1 Raio de borda
  // ------------------------------------------------------------------------
  ERPVRaioBorda = 4; // botoes/campos/chips; se o skin nao suportar, aceita o do skin

  // ------------------------------------------------------------------------
  // 3.1 Nomes do conjunto de icones (arquivos PNG entregues em T69; aqui so
  // o nome logico usado por quem for montar a TImageList/cxImageList central)
  // ------------------------------------------------------------------------
  ERPVIconeNovo        = 'novo';
  ERPVIconeEditar      = 'editar';
  ERPVIconeExcluir     = 'excluir';
  ERPVIconeSalvar      = 'salvar';
  ERPVIconeFechar      = 'fechar';
  ERPVIconeConfirmar   = 'confirmar';
  ERPVIconeCancelar    = 'cancelar';
  ERPVIconeBuscar      = 'buscar';
  ERPVIconeAtualizar   = 'atualizar';
  ERPVIconeReenviar    = 'reenviar';
  ERPVIconeAlerta      = 'alerta';
  ERPVIconeErro        = 'erro';
  ERPVIconeInfo        = 'info';
  ERPVIconeSucesso     = 'sucesso';
  ERPVIconePastaVazia  = 'pasta_vazia';
  ERPVIconeSinc        = 'sinc'; // [NOVO] indicador de sincronizacao pendente (§2.4/ADR-011)

/// <summary>
///   Escala um valor em pixels (definido a 96 DPI, base dos tokens acima)
///   para o DPI atual da tela (UX-SPEC.md Secao 6: "multiplicar por
///   Screen.PixelsPerInch/96 na unit de tokens, nao pixels fixos soltos nos
///   forms"). Uso tipico: EscalarPx(ERPVAlturaControle).
/// </summary>
function EscalarPx(const APixels: Integer): Integer; overload;

/// <summary>
///   Mesma escala acima, mas usando o PPI de um controle/form especifico
///   (util quando o form ja tem Scaled=True e um Monitor.PixelsPerInch
///   proprio, em vez do PPI global de Screen).
/// </summary>
function EscalarPx(const APixels: Integer; const APPIOrigemOuDestino: Integer): Integer; overload;

implementation

function EscalarPx(const APixels: Integer): Integer;
begin
  Result := EscalarPx(APixels, Screen.PixelsPerInch);
end;

function EscalarPx(const APixels: Integer; const APPIOrigemOuDestino: Integer): Integer;
begin
  if APPIOrigemOuDestino <= 0 then
    Result := APixels
  else
    Result := MulDiv(APixels, APPIOrigemOuDestino, 96);
end;

end.
