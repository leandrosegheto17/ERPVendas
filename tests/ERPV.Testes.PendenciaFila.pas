unit ERPV.Testes.PendenciaFila;

(*
  T53 - testes DUnitX da regra de bloqueio por fila pendente (UX 4.2) com fake de
  IFilaRepository em memoria. Nao compilado (sem CLI); rodar na IDE junto do
  projeto de testes (inclui src\Negocio\ERPV.Negocio.PendenciaFila).
*)

interface

uses
  System.SysUtils, System.Generics.Collections, Data.DB,
  DUnitX.TestFramework,
  ERPV.Dominio.Enums,
  ERPV.Dominio.Contratos.IFilaRepository,
  ERPV.Negocio.PendenciaFila;

type
  TFilaMemoria = class(TInterfacedObject, IFilaRepository)
  public
    Pendentes: TList<string>; // 'VENDA|TIPO'
    constructor Create;
    destructor Destroy; override;
    procedure Adicionar(AVendaId: Integer; ATipo: TTipoFila);
    procedure Concluir(AVendaId: Integer; ATipo: TTipoFila);
    procedure Enfileirar(AVendaId: Integer; ATipo: TTipoFila; const AErro: string = '');
    function Listar(ASomentePendentes: Boolean): TDataSet;
    procedure MarcarConcluido(AId: Integer);
    procedure RegistrarFalha(AId: Integer; const AErro: string);
    function ContarPendencias: Integer;
    function ExistePendenciaPorVenda(AVendaId: Integer; ATipo: TTipoFila): Boolean;
  end;

  [TestFixture]
  TTestesPendenciaFila = class
  private
    FFila: TFilaMemoria;
    FFilaI: IFilaRepository;
  public
    [Setup] procedure Setup;
    [Test] procedure SemFila_NuncaBloqueia;
    [Test] procedure SemPendencia_NaoBloqueia;
    [Test] procedure Quitacao_Bloqueia;
    [Test] procedure Cancelamento_Bloqueia;
    [Test] procedure Email_NaoBloqueia;
    [Test] procedure OutraVenda_NaoBloqueia;
    [Test] procedure AposReenvioOk_Libera;
    [Test] procedure Contador_AcompanhaEnfileirarEConcluir;
  end;

implementation

{ TFilaMemoria }

constructor TFilaMemoria.Create;
begin
  inherited Create;
  Pendentes := TList<string>.Create;
end;

destructor TFilaMemoria.Destroy;
begin
  Pendentes.Free;
  inherited Destroy;
end;

procedure TFilaMemoria.Adicionar(AVendaId: Integer; ATipo: TTipoFila);
begin
  Enfileirar(AVendaId, ATipo);
end;

procedure TFilaMemoria.Concluir(AVendaId: Integer; ATipo: TTipoFila);
begin
  Pendentes.Remove(Format('%d|%s', [AVendaId, TipoFilaToStr(ATipo)]));
end;

procedure TFilaMemoria.Enfileirar(AVendaId: Integer; ATipo: TTipoFila;
  const AErro: string);
var
  Chave: string;
begin
  Chave := Format('%d|%s', [AVendaId, TipoFilaToStr(ATipo)]);
  if not Pendentes.Contains(Chave) then
    Pendentes.Add(Chave);
end;

function TFilaMemoria.Listar(ASomentePendentes: Boolean): TDataSet;
begin
  Result := nil;
end;

procedure TFilaMemoria.MarcarConcluido(AId: Integer);
begin
end;

procedure TFilaMemoria.RegistrarFalha(AId: Integer; const AErro: string);
begin
end;

function TFilaMemoria.ContarPendencias: Integer;
begin
  Result := Pendentes.Count;
end;

function TFilaMemoria.ExistePendenciaPorVenda(AVendaId: Integer;
  ATipo: TTipoFila): Boolean;
begin
  Result := Pendentes.Contains(Format('%d|%s', [AVendaId, TipoFilaToStr(ATipo)]));
end;

{ TTestesPendenciaFila }

procedure TTestesPendenciaFila.Setup;
begin
  FFila := TFilaMemoria.Create;
  FFilaI := FFila; // a interface assume a posse (refcount)
end;

procedure TTestesPendenciaFila.SemFila_NuncaBloqueia;
begin
  Assert.IsFalse(VendaBloqueadaPorFila(nil, 10));
end;

procedure TTestesPendenciaFila.SemPendencia_NaoBloqueia;
begin
  Assert.IsFalse(VendaBloqueadaPorFila(FFilaI, 10));
end;

procedure TTestesPendenciaFila.Quitacao_Bloqueia;
begin
  FFila.Adicionar(10, tfQuitacao);
  Assert.IsTrue(VendaBloqueadaPorFila(FFilaI, 10));
end;

procedure TTestesPendenciaFila.Cancelamento_Bloqueia;
begin
  FFila.Adicionar(10, tfCancelamento);
  Assert.IsTrue(VendaBloqueadaPorFila(FFilaI, 10));
end;

procedure TTestesPendenciaFila.Email_NaoBloqueia;
begin
  FFila.Adicionar(10, tfEmail);
  Assert.IsFalse(VendaBloqueadaPorFila(FFilaI, 10));
end;

procedure TTestesPendenciaFila.OutraVenda_NaoBloqueia;
begin
  FFila.Adicionar(11, tfQuitacao);
  Assert.IsFalse(VendaBloqueadaPorFila(FFilaI, 10));
end;

procedure TTestesPendenciaFila.AposReenvioOk_Libera;
begin
  FFila.Adicionar(10, tfQuitacao);
  Assert.IsTrue(VendaBloqueadaPorFila(FFilaI, 10));
  FFila.Concluir(10, tfQuitacao);
  Assert.IsFalse(VendaBloqueadaPorFila(FFilaI, 10));
end;

procedure TTestesPendenciaFila.Contador_AcompanhaEnfileirarEConcluir;
begin
  Assert.AreEqual(0, FFilaI.ContarPendencias);
  FFila.Adicionar(10, tfQuitacao);
  FFila.Adicionar(10, tfQuitacao); // dedup (RN-08)
  FFila.Adicionar(11, tfCancelamento);
  Assert.AreEqual(2, FFilaI.ContarPendencias);
  FFila.Concluir(10, tfQuitacao);
  Assert.AreEqual(1, FFilaI.ContarPendencias);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestesPendenciaFila);

end.
