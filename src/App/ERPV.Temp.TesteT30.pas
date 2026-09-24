unit ERPV.Temp.TesteT30;
// TEMPORARIO (T30) - remover apos verificacao.
interface
uses ERPV.App.Root;
procedure RodarTesteT30(Root: TRootAplicacao);
implementation
uses
  System.SysUtils, Vcl.Dialogs, ERPV.Dominio.Enums,
  ERPV.Dominio.Cliente, ERPV.Dominio.Produto, ERPV.Dominio.Venda, ERPV.Dominio.VendaItem;

procedure Rel(const ACaso: string; AOk: Boolean);
begin
  if AOk then ShowMessage('T30 TESTE - OK: ' + ACaso) else ShowMessage('T30 TESTE - FALHA: ' + ACaso);
end;

function NovoCli(Root: TRootAplicacao; const ANome, ADoc: string; ATipo: TTipoPessoa): Integer;
var C: TCliente;
begin
  C := TCliente.Create;
  try
    C.Nome := ANome; C.TipoPessoa := ATipo; C.CpfCnpj := ADoc;
    C.Email := 't30@teste.com'; C.Ativo := True;
    Result := Root.ClienteService.Salvar(C);
  finally
    C.Free;
  end;
end;

function NovoProd(Root: TRootAplicacao; const ADesc: string): Integer;
var P: TProduto;
begin
  P := TProduto.Create;
  try
    P.Descricao := ADesc; P.Unidade := 'UN'; P.PrecoUnitario := 10; P.Ativo := True;
    Result := Root.ProdutoService.Salvar(P);
  finally
    P.Free;
  end;
end;

procedure RodarTesteT30(Root: TRootAplicacao);
var
  CliSem, CliCom, ProSem, ProCom, IdVenda: Integer;
  V: TVenda;
  I: TVendaItem;
  C: TCliente;
  P: TProduto;
begin
  CliSem := 0; CliCom := 0; ProSem := 0; ProCom := 0; IdVenda := 0;
  try
    try
      CliSem := NovoCli(Root, 'T30 Sem Venda', '11144477735', tpFisica);
      CliCom := NovoCli(Root, 'T30 Com Venda', '11444777000161', tpJuridica);
      ProSem := NovoProd(Root, 'T30 Prod Sem Venda');
      ProCom := NovoProd(Root, 'T30 Prod Com Venda');

      V := TVenda.Create;
      try
        V.ClienteId := CliCom;
        I := TVendaItem.Create;
        I.ProdutoId := ProCom; I.Quantidade := 1; I.PrecoUnitario := 10;
        V.Itens.Add(I);
        IdVenda := Root.VendaService.Salvar(V);
      finally
        V.Free;
      end;

      Rel('cliente sem venda: reExcluido', Root.ClienteService.Excluir(CliSem) = reExcluido);
      C := Root.ClienteService.Obter(CliSem);
      try
        Rel('cliente sem venda: nao existe mais', C = nil);
      finally
        C.Free;
      end;

      Rel('cliente com venda: reInativado', Root.ClienteService.Excluir(CliCom) = reInativado);
      C := Root.ClienteService.Obter(CliCom);
      try
        Rel('cliente com venda: ainda existe com Ativo=False', (C <> nil) and not C.Ativo);
      finally
        C.Free;
      end;

      Rel('produto sem venda: reExcluido', Root.ProdutoService.Excluir(ProSem) = reExcluido);
      P := Root.ProdutoService.Obter(ProSem);
      try
        Rel('produto sem venda: nao existe mais', P = nil);
      finally
        P.Free;
      end;

      Rel('produto com venda: reInativado', Root.ProdutoService.Excluir(ProCom) = reInativado);
      P := Root.ProdutoService.Obter(ProCom);
      try
        Rel('produto com venda: ainda existe com Ativo=False', (P <> nil) and not P.Ativo);
      finally
        P.Free;
      end;
    except
      on E: Exception do ShowMessage('T30 TESTE - FALHA inesperada: ' + E.Message);
    end;
    // limpeza: vendas antes (pelo repositorio), depois cadastros (agora sem venda => fisico)
    try if IdVenda > 0 then Root.VendaRepository.Excluir(IdVenda); except end;
    try if ProSem > 0 then Root.ProdutoService.Excluir(ProSem); except end;
    try if ProCom > 0 then Root.ProdutoService.Excluir(ProCom); except end;
    try if CliSem > 0 then Root.ClienteService.Excluir(CliSem); except end;
    try if CliCom > 0 then Root.ClienteService.Excluir(CliCom); except end;
  except
  end;
end;
end.
