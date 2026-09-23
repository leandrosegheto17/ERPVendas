program ERPVendas;

{
  Esqueleto do projeto (T07, Lote 2), agora plugado ao composition root real
  (T13, src\App\ERPV.App.Root): TentarIniciarAplicacao monta Config/Log/
  Tratador de excecoes/Conexao (DI manual por construtor, ADR-001) antes de
  qualquer form ser criado. Se a montagem falhar (INI ausente/invalido ou
  banco inacessivel), a mensagem amigavel ja foi mostrada dentro de
  TentarIniciarAplicacao e a aplicacao encerra aqui, sem abrir nenhum form
  e sem crash cru. Plataforma-alvo: Win32 (fixada em
  docs/ambiente-licencas.md Seção 6, DEC-02).
}

uses
  Vcl.Forms,
  ERPV.App.Root in 'src\App\ERPV.App.Root.pas',
  ERPV.UI.FormBaseEdicao in 'src\UI\ERPV.UI.FormBaseEdicao.pas',
  ERPV.UI.FormBaseLista in 'src\UI\ERPV.UI.FormBaseLista.pas',
  ERPV.UI.FormMain in 'src\UI\ERPV.UI.FormMain.pas' {FormMain},
  ERPV.UI.FormTesteTema in 'src\UI\ERPV.UI.FormTesteTema.pas',
  ERPV.UI.Tema in 'src\UI\ERPV.UI.Tema.pas',
  ERPV.UI.Tokens in 'src\UI\ERPV.UI.Tokens.pas';

{$R *.res}

var
  Root: TRootAplicacao;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;

  if TentarIniciarAplicacao(Root) then
  begin
    try
      AplicarTema; // skin uma unica vez, antes de criar qualquer form (T14)
      Application.CreateForm(TFormMain, FormMain);
      FormMain.Configurar(Root.Configuracao.Financeiro.BaseUrl);
      Application.Run;
    finally
      Root.Free;
    end;
  end;
end.
