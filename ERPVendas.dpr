program ERPVendas;

{
  Esqueleto do projeto (T07, Lote 2). Plataforma-alvo: Win32 (fixada em
  docs/ambiente-licencas.md Seção 6, DEC-02). Composition root real
  (montagem de Config/Log/Conexão/repositórios/serviços via DI manual por
  construtor) chega em T13 (src/App/ERPV.App.Root); por ora este .dpr só
  sobe o form placeholder de T07 para provar que o projeto compila e abre
  uma janela.
}

uses
  Vcl.Forms,
  ERPV.UI.FormMain in 'src\UI\ERPV.UI.FormMain.pas' {FormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
