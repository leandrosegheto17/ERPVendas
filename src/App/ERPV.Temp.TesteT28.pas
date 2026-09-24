unit ERPV.Temp.TesteT28;
// TEMPORARIO (T28/T29) - remover apos verificacao.
interface
uses ERPV.App.Root;
procedure RodarTesteT28(Root: TRootAplicacao);
implementation
uses
  System.SysUtils, Vcl.Dialogs, ERPV.Core.Erros, ERPV.Dominio.Enums,
  ERPV.Dominio.Cliente, ERPV.Dominio.Produto, ERPV.Dominio.Venda, ERPV.Dominio.VendaItem;

procedure Rel(const ACaso: string; AOk: Boolean);
begin
  if AOk then ShowMessage('T28/T29 TESTE - OK: ' + ACaso) else ShowMessage('T28/T29 TESTE - FALHA: ' + ACaso);
end;

procedure AddItem(AVenda: TVenda; AProd, AQtd: Integer; APreco: Currency);
var I: TVendaItem;
begin
  I := TVendaItem.Create;
  I.ProdutoId := AProd; I.Quantidade := AQtd; I.PrecoUnitario := APreco;
  AVenda.Itens.Add(I);
end;

function Recusa(Root: TRootAplicacao; AVenda: TVenda): Boolean;
begin
  Result := False;
  try
    Root.VendaService.Salvar(AVenda);
  except
    on E: ERegraNegocio do
    begin
      ShowMessage('T28/T29 TESTE - Motivo: ' + E.Message);
      Result := True;
    end;
  end;
end;

function RecusaExcluir(Root: TRootAplicacao; AId: Integer): Boolean;
begin
  Result := False;
  try
    Root.VendaService.Excluir(AId);
  except
    on E: ERegraNegocio do
    begin
      ShowMessage('T28/T29 TESTE - Motivo: ' + E.Message);
      Result := True;
    end;
  end;
end;

procedure RodarTesteT28(Root: TRootAplicacao);
var
  Cli: TCliente;
  P1, P2: TProduto;
  V, V2, V3: TVenda;
  Id: Integer;
  IdsVenda: array of Integer;
  I: Integer;
begin
  Cli := TCliente.Create; P1 := TProduto.Create; P2 := TProduto.Create;
  V := TVenda.Create;
  try
    try
      Cli.Nome := 'T28 Cliente'; Cli.TipoPessoa := tpFisica; Cli.CpfCnpj := '11144477735';
      Cli.Email := 't28@teste.com'; Cli.Ativo := True;
      Root.ClienteService.Salvar(Cli);
      P1.Descricao := 'T28 Prod 1'; P1.Unidade := 'UN'; P1.PrecoUnitario := 10; P1.Ativo := True;
      Root.ProdutoService.Salvar(P1);
      P2.Descricao := 'T28 Prod 2'; P2.Unidade := 'UN'; P2.PrecoUnitario := 2.5; P2.Ativo := True;
      Root.ProdutoService.Salvar(P2);

      // --- T28: total e snapshot (valores digitados ignorados) ---
      V.ClienteId := Cli.Id;
      V.ValorTotal := 9999;
      AddItem(V, P1.Id, 2, 777);     // 2 x 10 = 20
      AddItem(V, P2.Id, 3, 888);     // 3 x 2.5 = 7.5
      Id := Root.VendaService.Salvar(V);
      SetLength(IdsVenda, 1); IdsVenda[0] := Id;
      V2 := Root.VendaService.Obter(Id);
      try
        Rel('total recalculado ignora total digitado (27.50)',
          (V2 <> nil) and (V2.ValorTotal = 27.5));
        Rel('preco do item ignora o digitado (10 e 2.50)',
          (V2.Itens.Count = 2) and (V2.Itens[0].PrecoUnitario = 10) and (V2.Itens[1].PrecoUnitario = 2.5));
      finally
        V2.Free;
      end;

      // mudar preco do produto depois nao altera itens gravados
      P1.PrecoUnitario := 50;
      Root.ProdutoService.Salvar(P1);
      V2 := Root.VendaService.Obter(Id);
      try
        Rel('mudar preco do produto nao altera itens relidos',
          (V2.Itens[0].PrecoUnitario = 10) and (V2.ValorTotal = 27.5));
        // editar Pendente: item existente mantem snapshot; item novo pega preco atual
        V2.ValorTotal := 1;
        AddItem(V2, P1.Id, 1, 1);  // novo item, mesmo produto ja usado no item 0? item 0 consome snapshot; este pega 50
        Root.VendaService.Salvar(V2);
      finally
        V2.Free;
      end;
      V3 := Root.VendaService.Obter(Id);
      try
        Rel('editar Pendente funciona: snapshot mantido, item novo com preco atual, total 77.50',
          (V3.Itens.Count = 3) and (V3.Itens[0].PrecoUnitario = 10) and (V3.Itens[2].PrecoUnitario = 50)
          and (V3.ValorTotal = 77.5));
      finally
        V3.Free;
      end;

      // --- T29: Quitada ---
      Root.VendaRepository.AtualizarStatus(Id, svQuitada, Now, '');
      V2 := Root.VendaService.Obter(Id);
      try
        V2.Status := svPendente; // objeto do chamador mentindo: nao deve ser confiado
        Rel('editar Quitada recusada (ERegraNegocio)', Recusa(Root, V2));
      finally
        V2.Free;
      end;
      Rel('excluir Quitada recusada (ERegraNegocio)', RecusaExcluir(Root, Id));

      // --- T29: Cancelada ---
      Root.VendaRepository.AtualizarStatus(Id, svCancelada, 0, 'teste T28');
      V2 := Root.VendaService.Obter(Id);
      try
        V2.Status := svPendente;
        Rel('editar Cancelada recusada (ERegraNegocio)', Recusa(Root, V2));
      finally
        V2.Free;
      end;
      Rel('excluir Cancelada recusada (ERegraNegocio)', RecusaExcluir(Root, Id));

      // limpeza da venda: volta para Pendente e exclui via Service
      Root.VendaRepository.AtualizarStatus(Id, svPendente, 0, '');
      Root.VendaService.Excluir(Id);
      Rel('excluir Pendente funciona', Root.VendaService.Obter(Id) = nil);
    except
      on E: Exception do ShowMessage('T28/T29 TESTE - FALHA inesperada: ' + E.Message);
    end;
    for I := 0 to High(IdsVenda) do
      try Root.VendaRepository.Excluir(IdsVenda[I]); except end;
    try Root.ProdutoService.Excluir(P1.Id); except end;
    try Root.ProdutoService.Excluir(P2.Id); except end;
    try Root.ClienteService.Excluir(Cli.Id); except end;
  finally
    V.Free; Cli.Free; P1.Free; P2.Free;
  end;
end;
end.
