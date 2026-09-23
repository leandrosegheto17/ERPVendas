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
  ERPV.UI.FormMain in 'src\UI\ERPV.UI.FormMain.pas' {FormMain};

{$R *.res}

var
  Root: TRootAplicacao;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;

  if TentarIniciarAplicacao(Root) then
  begin
    try
      Application.CreateForm(TFormMain, FormMain);
      Application.Run;
    finally
      Root.Free;
    end;
  end;
end.
