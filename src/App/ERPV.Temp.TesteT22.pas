unit ERPV.Temp.TesteT22;

{ TEMPORARIO (remover apos teste): execução real de T22 e T21. }

interface

uses
  ERPV.App.Root;

procedure RodarTesteT22(ARoot: TRootAplicacao);

implementation

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Vcl.Dialogs,
  ERPV.Core.Erros,
  ERPV.Dominio.Produto;

var
  GLinhas: TStringList;
  GN: Integer;

procedure Linha(const ADescr, AEsperado, AObtido: string);
var
  LRes: string;
begin
  Inc(GN);
  if AEsperado = AObtido then
    LRes := 'OK'
  else
    LRes := 'FALHOU';
  GLinhas.Add(Format('%d. %s: esperado [%s] obtido [%s] %s',
    [GN, ADescr, AEsperado, AObtido, LRes]));
end;

function Resultado(ARoot: TRootAplicacao; const ADescr, AUnid: string;
  APreco: Currency): string;
var
  P: TProduto;
begin
  P := TProduto.Create;
  try
    P.Descricao := ADescr;
    P.Unidade := AUnid;
    P.PrecoUnitario := APreco;
    try
      ARoot.ProdutoService.Salvar(P);
      Result := 'sem erro';
    except
      on E: EValidacao do
        Result := E.Campo + '|' + E.Message;
    end;
  finally
    P.Free;
  end;
end;

function Contar(ARoot: TRootAplicacao; const AFiltro: string;
  AInativos: Boolean): Integer;
var
  DS: TDataSet;
begin
  Result := 0;
  DS := ARoot.ProdutoService.ListarDataSet(AFiltro, AInativos);
  try
    DS.First;
    while not DS.Eof do
    begin
      Inc(Result);
      DS.Next;
    end;
  finally
    DS.Free;
  end;
end;

procedure RodarTesteT22(ARoot: TRootAplicacao);
const
  NOME = 'Zzteste T22 Item';
var
  P, R: TProduto;
  Id, IdAtivo: Integer;
begin
  GLinhas := TStringList.Create;
  GN := 0;
  Id := 0;
  IdAtivo := 0;
  try
    try
      Linha('descricao vazia', 'Descricao|Informe a descrição',
        Resultado(ARoot, '   ', 'UN', 1));
      Linha('unidade vazia', 'Unidade|Informe a unidade',
        Resultado(ARoot, NOME, '  ', 1));
      Linha('preco -1', 'Preco|Preço inválido', Resultado(ARoot, NOME, 'UN', -1));

      // preco 0 valido: persiste e apaga
      P := TProduto.Create;
      try
        P.Descricao := NOME + ' zero';
        P.Unidade := 'UN';
        P.PrecoUnitario := 0;
        Linha('preco 0 valido (Id>0)', 'True',
          BoolToStr(ARoot.ProdutoService.Salvar(P) > 0, True));
        ARoot.ProdutoService.Excluir(P.Id);
      finally
        P.Free;
      end;

      // valido persiste + INSERT RETURNING
      P := TProduto.Create;
      try
        P.Descricao := '  ' + NOME + '  ';
        P.Unidade := ' UN ';
        P.PrecoUnitario := 12.34;
        Id := ARoot.ProdutoService.Salvar(P);
        Linha('valido persiste (Id>0)', 'True', BoolToStr(Id > 0, True));
        Linha('INSERT RETURNING Id na entidade', 'True', BoolToStr(P.Id = Id, True));
      finally
        P.Free;
      end;

      R := ARoot.ProdutoService.Obter(Id);
      try
        Linha('obter existe', 'True', BoolToStr(R <> nil, True));
        if R <> nil then
        begin
          Linha('obter descricao (Trim)', NOME, R.Descricao);
          Linha('obter unidade (Trim)', 'UN', R.Unidade);
          Linha('obter preco Currency', CurrToStr(12.34), CurrToStr(R.PrecoUnitario));
          Linha('obter Ativo', 'True', BoolToStr(R.Ativo, True));

          // edicao do mesmo Id
          R.PrecoUnitario := 20.5;
          Linha('edicao devolve mesmo Id', IntToStr(Id),
            IntToStr(ARoot.ProdutoService.Salvar(R)));
        end;
      finally
        R.Free;
      end;

      R := ARoot.ProdutoService.Obter(Id);
      try
        Linha('apos edicao preco', CurrToStr(20.5), CurrToStr(R.PrecoUnitario));
        R.Ativo := False;
        ARoot.ProdutoService.Salvar(R);
      finally
        R.Free;
      end;
      R := ARoot.ProdutoService.Obter(Id);
      try
        Linha('releitura Ativo=False', 'False', BoolToStr(R.Ativo, True));
      finally
        R.Free;
      end;

      // segundo produto ativo para a contagem
      P := TProduto.Create;
      try
        P.Descricao := NOME + ' ativo';
        P.Unidade := 'UN';
        P.PrecoUnitario := 1;
        IdAtivo := ARoot.ProdutoService.Salvar(P);
      finally
        P.Free;
      end;
      Linha('lista sem inativos (so o ativo)', '1',
        IntToStr(Contar(ARoot, 'Zzteste T22', False)));
      Linha('lista com inativos (ambos)', '2',
        IntToStr(Contar(ARoot, 'Zzteste T22', True)));

      ARoot.ProdutoService.Excluir(Id);
      Linha('excluir: obter do excluido e nil', 'True',
        BoolToStr(ARoot.ProdutoService.Obter(Id) = nil, True));
      Id := 0;
      ARoot.ProdutoService.Excluir(IdAtivo);
      IdAtivo := 0;
      Linha('apos excluir tudo, lista com inativos', '0',
        IntToStr(Contar(ARoot, 'Zzteste T22', True)));
    except
      on E: Exception do
        GLinhas.Add('EXCECAO: ' + E.ClassName + ' - ' + E.Message);
    end;
    // limpeza defensiva
    try
      if Id > 0 then
        ARoot.ProdutoService.Excluir(Id);
      if IdAtivo > 0 then
        ARoot.ProdutoService.Excluir(IdAtivo);
    except
    end;
    ShowMessage('TESTE T22/T21' + sLineBreak + GLinhas.Text);
  finally
    FreeAndNil(GLinhas);
  end;
end;

end.
