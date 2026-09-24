unit ERPV.UI.FormEdicaoCliente;

{
  T20 (Lote 4) - Edicao de Cliente (UX-SPEC 2.3, 5; ADR-011).
  Herda TFormBaseEdicao (T15). 100% em codigo (sem .dfm).

  CONTRATO (usado pela T19):
    TFormEdicaoCliente.Create(AOwner, AService, ACliente)
    ACliente = nil -> novo cliente. ShowModal = mrOk se gravou, senao mrCancel.
    A tela trabalha numa COPIA da entidade; ao gravar com sucesso copia o
    resultado (Id, campos normalizados) de volta para ACliente (se informado).
    ACliente continua sendo do chamador (a tela nunca o libera).

  Decisoes:
  - Regra de negocio so no servico. A validacao visual usa apenas
    ERPV.Core.Validadores (NormalizarDocumento/CpfValido/CnpjValido/EmailValido)
    e as mesmas mensagens literais do servico.
  - TFormBaseEdicao.Confirmar faz Validar -> Gravar -> mrOk e nao permite
    "falhar" em Gravar sem excecao. Por isso a chamada ao servico (Salvar)
    acontece DENTRO de Validar (apos a validacao visual); EValidacao vira erro
    no campo (E.Campo) e Validar devolve False; Gravar fica vazio.
  - Borda do campo: cada editor fica dentro de um painel-moldura (padding 1 px
    normal/erro, 2 px em foco), cor so de Tokens; funciona igual com qualquer
    skin. Erro = moldura vermelha + texto abaixo com icone (nunca so cor).
  - Telefone: TcxTextEdit sem mascara (fixos/celulares tem tamanhos diferentes;
    o servico nao valida nem normaliza telefone). Guardado como digitado.
  - Mudar o tipo de pessoa limpa o documento e a mascara e remove o erro do
    campo (revalidar um campo recem-limpo so geraria "Informe o CPF/CNPJ").
}

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  cxEdit, cxTextEdit, cxMaskEdit,
  ERPV.Core.Erros, ERPV.Core.Validadores,
  ERPV.Dominio.Cliente, ERPV.Negocio.ClienteService,
  ERPV.UI.Tokens, ERPV.UI.Tema, ERPV.UI.FormBaseEdicao;

type
  TCampo = (cNome, cDoc, cEmail, cTel, cEnd);

  TFormEdicaoCliente = class(TFormBaseEdicao)
  private
    FService: TClienteService;
    FDestino: TCliente;   // do chamador (pode ser nil); nao liberado aqui
    FCliente: TCliente;   // copia de trabalho (propria)
    FCarregando: Boolean;
    FProximoTop: Integer;
    FRbFisica: TRadioButton;
    FRbJuridica: TRadioButton;
    FEdtNome: TcxTextEdit;
    FEdtDoc: TcxMaskEdit;
    FEdtEmail: TcxTextEdit;
    FEdtTel: TcxTextEdit;
    FEdtEnd: TcxTextEdit;
    FChkAtivo: TCheckBox;
    FEdit: array[TCampo] of TWinControl;
    FMoldura: array[TCampo] of TPanel;
    FErro: array[TCampo] of TLabel;

    function NovoBloco(AAltura: Integer): TPanel;
    function NovoRotulo(ABloco: TPanel; const ACaption: string): TLabel;
    function NovaMoldura(ABloco: TPanel; ACampo: TCampo): TPanel;
    function NovoErro(ABloco: TPanel; ACampo: TCampo): TLabel;
    function NovoTexto(ABloco: TPanel; ACampo: TCampo;
      const ARotulo: string): TcxTextEdit;
    procedure MontarCampos;

    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure TipoClick(Sender: TObject);
    procedure AtivoClick(Sender: TObject);

    function CampoDe(ASender: TObject; out ACampo: TCampo): Boolean;
    function CampoPorNome(const ANome: string; out ACampo: TCampo): Boolean;
    procedure AtualizarMoldura(ACampo: TCampo);
    procedure MostrarErro(ACampo: TCampo; const AMensagem: string);
    procedure LimparErro(ACampo: TCampo);
    function TemErro(ACampo: TCampo): Boolean;
    function MensagemCampo(ACampo: TCampo): string;
    function ValidarCampo(ACampo: TCampo): Boolean;
    function TipoAtual: TTipoPessoa;
    procedure AplicarMascara;
    procedure Carregar;
    procedure LerParaEntidade;
  protected
    function Validar: Boolean; override;
    procedure Gravar; override;
  public
    constructor Create(AOwner: TComponent; AService: TClienteService;
      ACliente: TCliente); reintroduce;
    destructor Destroy; override;
  end;

implementation

const
  // Segundo campo ';1;' = a mascara GUARDA os literais em Text. Com ';0;' o campo
  // mostrava o CPF carregado sem pontuacao (achado real no teste de T20).
  // Toda leitura passa por NormalizarDocumento, entao so digitos seguem adiante.
  MascaraCpf = '999.999.999-99;1;_';
  MascaraCnpj = '99.999.999/9999-99;1;_';
  cAlturaControleRadio = 28;
  cAlturaRotulo = 18;
  cAlturaMoldura = 32;
  cAlturaErro = 18;

{ TFormEdicaoCliente }

constructor TFormEdicaoCliente.Create(AOwner: TComponent;
  AService: TClienteService; ACliente: TCliente);
begin
  inherited Create(AOwner);
  if AService = nil then
    raise EArgumentException.Create('TFormEdicaoCliente: servico nao informado.');
  FService := AService;
  FDestino := ACliente;
  FCliente := TCliente.Create;
  if ACliente <> nil then
  begin
    FCliente.Id := ACliente.Id;
    FCliente.Nome := ACliente.Nome;
    FCliente.TipoPessoa := ACliente.TipoPessoa;
    FCliente.CpfCnpj := ACliente.CpfCnpj;
    FCliente.Endereco := ACliente.Endereco;
    FCliente.Telefone := ACliente.Telefone;
    FCliente.Email := ACliente.Email;
    FCliente.Ativo := ACliente.Ativo;
  end;

  Caption := 'Cliente';
  MontarCampos;
  Carregar;
end;

destructor TFormEdicaoCliente.Destroy;
begin
  FCliente.Free;
  inherited Destroy;
end;

{ ---- construcao da tela ---- }

// Bloco = 1 campo (rotulo + moldura + erro), empilhado por Top (alTop).
function TFormEdicaoCliente.NovoBloco(AAltura: Integer): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := PnlCampos;
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.Color := clERPVSuperficie;
  Result.Align := alTop;
  Result.Height := AAltura;
  Result.Top := FProximoTop; // garante a ordem visual = ordem de criacao
  Inc(FProximoTop, AAltura);
end;

function TFormEdicaoCliente.NovoRotulo(ABloco: TPanel;
  const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := ABloco;
  Result.AutoSize := False;
  Result.Align := alTop;
  Result.Height := EscalarPx(cAlturaRotulo);
  Result.Layout := tlCenter;
  Result.Caption := ACaption;
  Result.Font.Name := ERPVFontePrincipal;
  Result.Font.Size := ERPVTamRotuloCampo;
  Result.Font.Style := [fsBold];
  Result.Font.Color := clERPVTextoPrincipal;
  Result.Top := 0;
end;

function TFormEdicaoCliente.NovaMoldura(ABloco: TPanel;
  ACampo: TCampo): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := ABloco;
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.Align := alTop;
  Result.Height := EscalarPx(cAlturaMoldura);
  Result.Top := EscalarPx(cAlturaRotulo);
  FMoldura[ACampo] := Result;
end;

function TFormEdicaoCliente.NovoErro(ABloco: TPanel; ACampo: TCampo): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := ABloco;
  Result.AutoSize := False;
  Result.Align := alTop;
  Result.Height := EscalarPx(cAlturaErro);
  Result.Layout := tlCenter;
  Result.Caption := '';
  Result.Font.Name := ERPVFontePrincipal;
  Result.Font.Size := ERPVTamCorpo;
  Result.Font.Color := clERPVErroTexto;
  Result.Top := EscalarPx(cAlturaRotulo + cAlturaMoldura);
  FErro[ACampo] := Result;
end;

function TFormEdicaoCliente.NovoTexto(ABloco: TPanel; ACampo: TCampo;
  const ARotulo: string): TcxTextEdit;
begin
  // ordem de criacao dos alTop: rotulo, moldura, erro (Top crescente)
  NovoRotulo(ABloco, ARotulo);
  NovaMoldura(ABloco, ACampo);
  NovoErro(ABloco, ACampo);
  Result := TcxTextEdit.Create(Self);
  Result.Parent := FMoldura[ACampo];
  Result.Align := alClient;
  Result.Style.BorderStyle := ebsNone;
  Result.Properties.OnChange := EditChange;
  Result.OnEnter := EditEnter;
  Result.OnExit := EditExit;
  FEdit[ACampo] := Result;
end;

procedure TFormEdicaoCliente.MontarCampos;
var
  Bloco, Linha: TPanel;
  Sub: TLabel;
  Rot: TLabel;
  C: TCampo;
  Legenda: TLabel;
begin
  FProximoTop := 0;
  PnlCampos.AutoSize := False;

  // subtitulo
  Bloco := NovoBloco(EscalarPx(28));
  Sub := TLabel.Create(Self);
  Sub.Parent := Bloco;
  Sub.Align := alClient;
  Sub.Layout := tlCenter;
  Sub.Font.Name := ERPVFontePrincipal;
  Sub.Font.Size := ERPVTamSubtitulo;
  Sub.Font.Style := [fsBold];
  Sub.Font.Color := clERPVTextoPrincipal;
  if FDestino = nil then
    Sub.Caption := 'Novo cliente'
  else
    Sub.Caption := 'Editar cliente';

  // tipo de pessoa (sem erro proprio)
  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaControleRadio));
  Rot := NovoRotulo(Bloco, 'Tipo de pessoa');
  Linha := TPanel.Create(Self);
  Linha.Parent := Bloco;
  Linha.BevelOuter := bvNone;
  Linha.ParentBackground := False;
  Linha.Color := clERPVSuperficie;
  Linha.Align := alTop;
  Linha.Height := EscalarPx(cAlturaControleRadio);
  Linha.Top := EscalarPx(cAlturaRotulo);
  FRbFisica := TRadioButton.Create(Self);
  FRbFisica.Parent := Linha;
  FRbFisica.Caption := 'Física';
  FRbFisica.SetBounds(0, 0, EscalarPx(120), EscalarPx(cAlturaControleRadio));
  FRbFisica.Checked := True;
  FRbFisica.OnClick := TipoClick;
  FRbJuridica := TRadioButton.Create(Self);
  FRbJuridica.Parent := Linha;
  FRbJuridica.Caption := 'Jurídica';
  FRbJuridica.SetBounds(EscalarPx(130), 0, EscalarPx(120),
    EscalarPx(cAlturaControleRadio));
  FRbJuridica.OnClick := TipoClick;
  Rot.FocusControl := FRbFisica;

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtNome := NovoTexto(Bloco, cNome, 'Nome/Razão Social *');

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  NovoRotulo(Bloco, 'CPF/CNPJ *');
  NovaMoldura(Bloco, cDoc);
  NovoErro(Bloco, cDoc);
  FEdtDoc := TcxMaskEdit.Create(Self);
  FEdtDoc.Parent := FMoldura[cDoc];
  FEdtDoc.Align := alClient;
  FEdtDoc.Style.BorderStyle := ebsNone;
  FEdtDoc.Properties.OnChange := EditChange;
  FEdtDoc.OnEnter := EditEnter;
  FEdtDoc.OnExit := EditExit;
  FEdit[cDoc] := FEdtDoc;

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtEmail := NovoTexto(Bloco, cEmail, 'E-mail *');

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtTel := NovoTexto(Bloco, cTel, 'Telefone');

  Bloco := NovoBloco(EscalarPx(cAlturaRotulo + cAlturaMoldura + cAlturaErro));
  FEdtEnd := NovoTexto(Bloco, cEnd, 'Endereço');

  // Ativo + legenda
  Bloco := NovoBloco(EscalarPx(cAlturaControleRadio));
  FChkAtivo := TCheckBox.Create(Self);
  FChkAtivo.Parent := Bloco;
  FChkAtivo.Caption := 'Ativo';
  FChkAtivo.SetBounds(0, 0, EscalarPx(120), EscalarPx(cAlturaControleRadio));
  FChkAtivo.Checked := True;
  FChkAtivo.OnClick := AtivoClick;
  Legenda := TLabel.Create(Self);
  Legenda.Parent := Bloco;
  Legenda.Align := alRight;
  Legenda.AutoSize := True;
  Legenda.Layout := tlCenter;
  Legenda.Caption := '* obrigatório';
  Legenda.Font.Name := ERPVFontePrincipal;
  Legenda.Font.Size := ERPVTamCorpo;
  Legenda.Font.Color := clERPVTextoSecundario;

  // molduras no estado inicial e cores dos rotulos ja definidas acima
  for C := Low(TCampo) to High(TCampo) do
    AtualizarMoldura(C);

  // tabulacao: campos em ordem (rodape ja vem da base)
  FRbFisica.TabOrder := 0;
  FRbJuridica.TabOrder := 1;
  FEdtNome.TabOrder := 0;
  FChkAtivo.TabOrder := 0;
  ClientHeight := FProximoTop + 2 * ERPVMargemPagina + ERPVAlturaFaixaMarca
    + EscalarPx(8);
end;

{ ---- estado visual ---- }

function TFormEdicaoCliente.CampoDe(ASender: TObject;
  out ACampo: TCampo): Boolean;
var
  C: TCampo;
begin
  Result := False;
  for C := Low(TCampo) to High(TCampo) do
    if FEdit[C] = ASender then
    begin
      ACampo := C;
      Exit(True);
    end;
end;

function TFormEdicaoCliente.CampoPorNome(const ANome: string;
  out ACampo: TCampo): Boolean;
begin
  Result := True;
  if SameText(ANome, 'Nome') then
    ACampo := cNome
  else if SameText(ANome, 'CpfCnpj') then
    ACampo := cDoc
  else if SameText(ANome, 'Email') then
    ACampo := cEmail
  else if SameText(ANome, 'Telefone') then
    ACampo := cTel
  else if SameText(ANome, 'Endereco') then
    ACampo := cEnd
  else
    Result := False;
end;

function TFormEdicaoCliente.TemErro(ACampo: TCampo): Boolean;
begin
  Result := FErro[ACampo].Caption <> '';
end;

// Foco = 2 px destaque; erro = 1 px vermelho; normal = 1 px borda de campo.
procedure TFormEdicaoCliente.AtualizarMoldura(ACampo: TCampo);
var
  Foco: Boolean;
  Pad: Integer;
begin
  Foco := FEdit[ACampo].Focused;
  if Foco then
  begin
    FMoldura[ACampo].Color := clERPVDestaque;
    Pad := 2;
  end
  else if TemErro(ACampo) then
  begin
    FMoldura[ACampo].Color := clERPVErroTexto;
    Pad := 1;
  end
  else
  begin
    FMoldura[ACampo].Color := clERPVBordaCampo;
    Pad := 1;
  end;
  FMoldura[ACampo].Padding.SetBounds(Pad, Pad, Pad, Pad);
end;

procedure TFormEdicaoCliente.MostrarErro(ACampo: TCampo;
  const AMensagem: string);
begin
  // icone (U+2716) + texto: nunca so cor (UX 5)
  FErro[ACampo].Caption := Char($2716) + ' ' + AMensagem;
  AtualizarMoldura(ACampo);
end;

procedure TFormEdicaoCliente.LimparErro(ACampo: TCampo);
begin
  FErro[ACampo].Caption := '';
  AtualizarMoldura(ACampo);
end;

procedure TFormEdicaoCliente.EditEnter(Sender: TObject);
var
  C: TCampo;
begin
  if CampoDe(Sender, C) then
    AtualizarMoldura(C);
end;

procedure TFormEdicaoCliente.EditExit(Sender: TObject);
var
  C: TCampo;
begin
  if not CampoDe(Sender, C) then
    Exit;
  // Focused ainda pode ser True aqui: forca o estado "sem foco" na moldura
  ValidarCampo(C);
  FMoldura[C].Color := clERPVBordaCampo;
  FMoldura[C].Padding.SetBounds(1, 1, 1, 1);
  if TemErro(C) then
    FMoldura[C].Color := clERPVErroTexto;
end;

procedure TFormEdicaoCliente.EditChange(Sender: TObject);
begin
  if not FCarregando then
    MarcarModificado;
end;

procedure TFormEdicaoCliente.AtivoClick(Sender: TObject);
begin
  if not FCarregando then
    MarcarModificado;
end;

procedure TFormEdicaoCliente.TipoClick(Sender: TObject);
begin
  if FCarregando then
    Exit;
  MarcarModificado;
  AplicarMascara;
  LimparErro(cDoc);
end;

function TFormEdicaoCliente.TipoAtual: TTipoPessoa;
begin
  if FRbJuridica.Checked then
    Result := tpJuridica
  else
    Result := tpFisica;
end;

// Formata so digitos no padrao da mascara (CPF 11 / CNPJ 14 digitos); se o
// tamanho nao bate, devolve os digitos como estao.
function FormatarDocumento(const ADigitos: string; AFisica: Boolean): string;
begin
  Result := ADigitos;
  if AFisica and (Length(ADigitos) = 11) then
    Result := Copy(ADigitos, 1, 3) + '.' + Copy(ADigitos, 4, 3) + '.' +
      Copy(ADigitos, 7, 3) + '-' + Copy(ADigitos, 10, 2)
  else if (not AFisica) and (Length(ADigitos) = 14) then
    Result := Copy(ADigitos, 1, 2) + '.' + Copy(ADigitos, 3, 3) + '.' +
      Copy(ADigitos, 6, 3) + '/' + Copy(ADigitos, 9, 4) + '-' + Copy(ADigitos, 13, 2);
end;

// Troca a mascara conforme o tipo; limpa o valor antes (evita texto orfao).
procedure TFormEdicaoCliente.AplicarMascara;
var
  Antes: Boolean;
begin
  Antes := FCarregando;
  FCarregando := True;
  try
    FEdtDoc.EditValue := Null;
    if TipoAtual = tpFisica then
      FEdtDoc.Properties.EditMask := MascaraCpf
    else
      FEdtDoc.Properties.EditMask := MascaraCnpj;
  finally
    FCarregando := Antes;
  end;
end;

{ ---- validacao visual (so chama Validadores; regra real = servico) ---- }

function TFormEdicaoCliente.MensagemCampo(ACampo: TCampo): string;
var
  Doc: string;
begin
  Result := '';
  case ACampo of
    cNome:
      if Trim(FEdtNome.Text) = '' then
        Result := 'Informe o nome';
    cDoc:
      begin
        Doc := NormalizarDocumento(FEdtDoc.Text);
        if Doc = '' then
          Result := 'Informe o CPF/CNPJ'
        else if (TipoAtual = tpFisica) and not CpfValido(Doc) then
          Result := 'CPF invalido'
        else if (TipoAtual = tpJuridica) and not CnpjValido(Doc) then
          Result := 'CNPJ invalido';
      end;
    cEmail:
      if Trim(FEdtEmail.Text) = '' then
        Result := 'Informe o e-mail'
      else if not EmailValido(Trim(FEdtEmail.Text)) then
        Result := 'E-mail invalido';
  end;
end;

function TFormEdicaoCliente.ValidarCampo(ACampo: TCampo): Boolean;
var
  Msg: string;
begin
  Msg := MensagemCampo(ACampo);
  Result := Msg = '';
  if Result then
    LimparErro(ACampo)
  else
    MostrarErro(ACampo, Msg);
end;

{ ---- dados ---- }

procedure TFormEdicaoCliente.Carregar;
begin
  FCarregando := True;
  try
    FRbFisica.Checked := FCliente.TipoPessoa = tpFisica;
    FRbJuridica.Checked := FCliente.TipoPessoa = tpJuridica;
    AplicarMascara;
    FEdtNome.Text := FCliente.Nome;
    FEdtDoc.EditValue := FormatarDocumento(FCliente.CpfCnpj, TipoAtual = tpFisica);
    FEdtEmail.Text := FCliente.Email;
    FEdtTel.Text := FCliente.Telefone;
    FEdtEnd.Text := FCliente.Endereco;
    FChkAtivo.Checked := FCliente.Ativo;
  finally
    FCarregando := False;
  end;
end;

procedure TFormEdicaoCliente.LerParaEntidade;
begin
  FCliente.TipoPessoa := TipoAtual;
  FCliente.Nome := Trim(FEdtNome.Text);
  FCliente.CpfCnpj := NormalizarDocumento(FEdtDoc.Text);
  FCliente.Email := Trim(FEdtEmail.Text);
  FCliente.Telefone := Trim(FEdtTel.Text);
  FCliente.Endereco := Trim(FEdtEnd.Text);
  FCliente.Ativo := FChkAtivo.Checked;
end;

// Validacao visual + chamada ao servico (ver nota no cabecalho).
function TFormEdicaoCliente.Validar: Boolean;
var
  C, Primeiro: TCampo;
  TemPrimeiro: Boolean;
  Campo: TCampo;
begin
  TemPrimeiro := False;
  Primeiro := cNome;
  for C := Low(TCampo) to High(TCampo) do
    if not ValidarCampo(C) and not TemPrimeiro then
    begin
      TemPrimeiro := True;
      Primeiro := C;
    end;
  if TemPrimeiro then
  begin
    FEdit[Primeiro].SetFocus;
    Exit(False);
  end;

  LerParaEntidade;
  try
    FService.Salvar(FCliente);
  except
    on E: EValidacao do
    begin
      if CampoPorNome(E.Campo, Campo) then
      begin
        MostrarErro(Campo, E.Message);
        FEdit[Campo].SetFocus;
      end
      else
        Notificar(utnErro, E.Message);
      Exit(False);
    end;
  end;

  if FDestino <> nil then
  begin
    FDestino.Id := FCliente.Id;
    FDestino.Nome := FCliente.Nome;
    FDestino.TipoPessoa := FCliente.TipoPessoa;
    FDestino.CpfCnpj := FCliente.CpfCnpj;
    FDestino.Endereco := FCliente.Endereco;
    FDestino.Telefone := FCliente.Telefone;
    FDestino.Email := FCliente.Email;
    FDestino.Ativo := FCliente.Ativo;
  end;
  Result := True;
end;

procedure TFormEdicaoCliente.Gravar;
begin
  // gravacao ja feita em Validar (ver nota no cabecalho da unit)
end;

end.
