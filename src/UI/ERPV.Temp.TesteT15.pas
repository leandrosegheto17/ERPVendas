unit ERPV.Temp.TesteT15;

{
  TEMPORARIO - exercita as bases da T15 (TFormBaseLista / TFormBaseEdicao).
  Remover esta unit, a linha do .dpr e a DCCReference do .dproj depois do teste.
}

interface

procedure RodarTesteT15;

implementation

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  ERPV.UI.Tema, ERPV.UI.FormBaseLista, ERPV.UI.FormBaseEdicao;

type
  TFilhoEdicao = class(TFormBaseEdicao)
  private
    procedure CampoChange(Sender: TObject);
  protected
    function Validar: Boolean; override;
    procedure Gravar; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TFilhoLista = class(TFormBaseLista)
  private
    FLog: TLabel;
    procedure Marca(const AMsg: string);
  protected
    procedure AoNovo; override;
    procedure AoEditar; override;
    procedure AoExcluir; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

constructor TFilhoEdicao.Create(AOwner: TComponent);
var
  E: TEdit;
begin
  inherited Create(AOwner);
  Caption := 'Teste - Edicao';
  ExibirExcluir := True;
  E := TEdit.Create(Self);
  E.Parent := PnlCampos;
  E.Left := 16;
  E.Top := 16;
  E.Width := 300;
  E.TextHint := 'Digite algo (marca como modificado)';
  E.OnChange := CampoChange;
end;

procedure TFilhoEdicao.CampoChange(Sender: TObject);
begin
  MarcarModificado;
end;

function TFilhoEdicao.Validar: Boolean;
begin
  Result := True;
end;

procedure TFilhoEdicao.Gravar;
begin
  Notificar(utnInfo, 'Gravou (Enter/Salvar funcionou)', PnlCampos);
end;

constructor TFilhoLista.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Teste - Lista';
  Titulo := 'Clientes (teste T15)';
  Subtitulo := '0 registros';
  FLog := TLabel.Create(Self);
  FLog.Parent := PnlConteudo;
  FLog.Left := 16;
  FLog.Top := 16;
  FLog.Caption := 'Checklist: Esc fecha; Enter=Editar; Tab: Novo>Editar>Excluir>Fechar';
end;

procedure TFilhoLista.Marca(const AMsg: string);
begin
  FLog.Caption := AMsg;
end;

procedure TFilhoLista.AoNovo;
var
  F: TFilhoEdicao;
  R: TModalResult;
begin
  F := TFilhoEdicao.Create(Self);
  try
    F.Caption := 'Teste - Novo';
    R := F.ShowModal;
    if R = mrOk then
      Marca('Edicao fechou com OK (Enter/Salvar)')
    else
      Marca('Edicao fechou sem gravar (Esc/Cancelar), modal=' + IntToStr(R));
  finally
    F.Free;
  end;
end;

procedure TFilhoLista.AoEditar;
begin
  Marca('AoEditar acionado (Enter ou botao Editar)');
  Notificar(utnInfo, 'Editar acionado', PnlConteudo);
end;

procedure TFilhoLista.AoExcluir;
begin
  Marca('AoExcluir acionado');
  Notificar(utnPergunta, 'Excluir este registro?');
end;

procedure RodarTesteT15;
var
  F: TFilhoLista;
begin
  F := TFilhoLista.Create(Application);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
