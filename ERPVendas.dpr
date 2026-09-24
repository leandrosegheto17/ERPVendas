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
  ERPV.Core.Validadores in 'src\Core\ERPV.Core.Validadores.pas',
  ERPV.Dados.ClienteRepository in 'src\Dados\ERPV.Dados.ClienteRepository.pas',
  ERPV.Dados.ProdutoRepository in 'src\Dados\ERPV.Dados.ProdutoRepository.pas',
  ERPV.Dados.VendaRepository in 'src\Dados\ERPV.Dados.VendaRepository.pas',
  ERPV.Dados.FilaRepository in 'src\Dados\ERPV.Dados.FilaRepository.pas',
  ERPV.Negocio.ClienteService in 'src\Negocio\ERPV.Negocio.ClienteService.pas',
  ERPV.Negocio.ProdutoService in 'src\Negocio\ERPV.Negocio.ProdutoService.pas',
  ERPV.Negocio.VendaService in 'src\Negocio\ERPV.Negocio.VendaService.pas',
  ERPV.Negocio.QuitacaoService in 'src\Negocio\ERPV.Negocio.QuitacaoService.pas',
  ERPV.UI.FormBaseEdicao in 'src\UI\ERPV.UI.FormBaseEdicao.pas',
  ERPV.UI.FormBaseLista in 'src\UI\ERPV.UI.FormBaseLista.pas',
  ERPV.UI.FormEdicaoCliente in 'src\UI\ERPV.UI.FormEdicaoCliente.pas',
  ERPV.UI.FormEdicaoProduto in 'src\UI\ERPV.UI.FormEdicaoProduto.pas',
  ERPV.UI.ConfirmacaoVenda in 'src\UI\ERPV.UI.ConfirmacaoVenda.pas',
  ERPV.UI.FormEdicaoVenda in 'src\UI\ERPV.UI.FormEdicaoVenda.pas',
  ERPV.UI.FormListaClientes in 'src\UI\ERPV.UI.FormListaClientes.pas',
  ERPV.UI.FormListaProdutos in 'src\UI\ERPV.UI.FormListaProdutos.pas',
  ERPV.UI.FormListaVendas in 'src\UI\ERPV.UI.FormListaVendas.pas',
  ERPV.UI.FormMain in'src\UI\ERPV.UI.FormMain.pas' {FormMain},
  ERPV.UI.FormTesteTema in 'src\UI\ERPV.UI.FormTesteTema.pas',
  ERPV.UI.Icones in 'src\UI\ERPV.UI.Icones.pas',
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
      FormMain.Configurar(Root.Configuracao.Financeiro.BaseUrl, Root.ClienteService,
        Root.ProdutoService, Root.VendaService, Root.QuitacaoService);
      Application.Run;
    finally
      Root.Free;
    end;
  end;
end.
