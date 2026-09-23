unit ERPV.UI.Icones;

{
  T69 (Lote 3) - Carga e aplicacao dos icones (UX-SPEC 3; ambiente-licencas 13).

  Le assets\icones\{16,24,32}\<nome>.png (nomes = constantes ERPVIcone* de
  ERPV.UI.Tokens) em uma TImageList por tamanho, com cache unico por processo.
  Tamanho escolhido pelo DPI atual: <=96 -> 16, <=144 -> 24, acima -> 32.

  Pasta: procurada a partir do .exe subindo diretorios (dev: Win32\Debug ->
  raiz do projeto; release: pasta assets\icones ao lado do .exe).

  DEGRADA SEM ERRO: pasta ou arquivo ausente/invalido => o icone simplesmente
  nao e aplicado (botao fica so com texto). Nenhuma rotina publica levanta
  excecao. O Caption do botao NUNCA e alterado (regra: nenhum botao so icone).
}

interface

uses
  System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls,
  cxButtons, ERPV.UI.Tokens;

/// <summary>Aplica o icone ao botao (OptionsImage). Sem icone disponivel: no-op.</summary>
procedure AplicarIcone(ABotao: TcxButton; const ANome: string);

/// <summary>Carrega o icone num TImage (banner/status bar). False = indisponivel.</summary>
function AplicarIconeImagem(AImagem: TImage; const ANome: string): Boolean;

/// <summary>Lado (px) do conjunto de icones para o DPI atual: 16, 24 ou 32.</summary>
function TamanhoIconeAtual: Integer;

implementation

uses
  Winapi.Windows, Vcl.Forms, Vcl.Imaging.pngimage;

const
  NOMES_ICONES: array[0..15] of string = (
    ERPVIconeNovo, ERPVIconeEditar, ERPVIconeExcluir, ERPVIconeSalvar,
    ERPVIconeFechar, ERPVIconeConfirmar, ERPVIconeCancelar, ERPVIconeBuscar,
    ERPVIconeAtualizar, ERPVIconeReenviar, ERPVIconeAlerta, ERPVIconeErro,
    ERPVIconeInfo, ERPVIconeSucesso, ERPVIconePastaVazia, ERPVIconeSinc);

var
  GPasta: string;
  GPastaProcurada: Boolean;
  GListas: array[0..2] of TImageList;   // 16, 24, 32
  GNomes: array[0..2] of TStringList;   // nome na ordem do indice da lista

function IndiceTamanho(ALado: Integer): Integer;
begin
  case ALado of
    16: Result := 0;
    24: Result := 1;
  else
    Result := 2;
  end;
end;

function TamanhoIconeAtual: Integer;
var
  Ppi: Integer;
begin
  Ppi := Screen.PixelsPerInch;
  if Ppi <= 96 then
    Result := 16
  else if Ppi <= 144 then
    Result := 24
  else
    Result := 32;
end;

function LocalizarPasta: string;
var
  Dir, Candidato: string;
  Nivel: Integer;
begin
  Result := '';
  try
    Dir := ExtractFilePath(ParamStr(0));
    for Nivel := 0 to 6 do
    begin
      Candidato := IncludeTrailingPathDelimiter(Dir) + 'assets' + PathDelim + 'icones';
      if DirectoryExists(Candidato) then
        Exit(Candidato);
      Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
      if Dir = '' then
        Break;
    end;
  except
    Result := '';
  end;
end;

function PastaIcones: string;
begin
  if not GPastaProcurada then
  begin
    GPastaProcurada := True;
    GPasta := LocalizarPasta;
  end;
  Result := GPasta;
end;

function ArquivoIcone(ALado: Integer; const ANome: string): string;
begin
  Result := '';
  if PastaIcones <> '' then
    Result := IncludeTrailingPathDelimiter(PastaIcones) + IntToStr(ALado)
      + PathDelim + ANome + '.png';
end;

procedure CarregarLista(ALado: Integer);
var
  Idx, I: Integer;
  Lista: TImageList;
  Png: TPngImage;
  Bmp: TBitmap;
  Arq: string;
begin
  Idx := IndiceTamanho(ALado);
  if GListas[Idx] <> nil then
    Exit;
  Lista := TImageList.Create(nil);
  Lista.ColorDepth := cd32Bit;
  Lista.Width := ALado;
  Lista.Height := ALado;
  GListas[Idx] := Lista;
  GNomes[Idx] := TStringList.Create;
  for I := Low(NOMES_ICONES) to High(NOMES_ICONES) do
  begin
    try
      Arq := ArquivoIcone(ALado, NOMES_ICONES[I]);
      if (Arq = '') or not FileExists(Arq) then
        Continue;
      Png := TPngImage.Create;
      try
        Png.LoadFromFile(Arq);
        Bmp := TBitmap.Create;
        try
          Bmp.Assign(Png);
          if (Bmp.Width = ALado) and (Bmp.Height = ALado) then
            GNomes[Idx].AddObject(NOMES_ICONES[I],
              TObject(NativeInt(Lista.Add(Bmp, nil))));
        finally
          Bmp.Free;
        end;
      finally
        Png.Free;
      end;
    except
      // arquivo corrompido/ilegivel: degrada (icone nao aplicado)
    end;
  end;
end;

function ObterIndice(const ANome: string; out ALista: TImageList): Integer;
var
  Idx, P: Integer;
begin
  Result := -1;
  ALista := nil;
  try
    Idx := IndiceTamanho(TamanhoIconeAtual);
    CarregarLista(TamanhoIconeAtual);
    P := GNomes[Idx].IndexOf(ANome);
    if P >= 0 then
    begin
      ALista := GListas[Idx];
      Result := Integer(NativeInt(GNomes[Idx].Objects[P]));
    end;
  except
    Result := -1;
    ALista := nil;
  end;
end;

procedure AplicarIcone(ABotao: TcxButton; const ANome: string);
var
  Lista: TImageList;
  Indice: Integer;
begin
  if ABotao = nil then
    Exit;
  try
    Indice := ObterIndice(ANome, Lista);
    if (Indice >= 0) and (Lista <> nil) then
    begin
      ABotao.OptionsImage.Images := Lista;
      ABotao.OptionsImage.ImageIndex := Indice;
    end;
  except
    // degrada: botao permanece so com texto
  end;
end;

function AplicarIconeImagem(AImagem: TImage; const ANome: string): Boolean;
var
  Arq: string;
  Png: TPngImage;
begin
  Result := False;
  if AImagem = nil then
    Exit;
  try
    Arq := ArquivoIcone(TamanhoIconeAtual, ANome);
    if (Arq = '') or not FileExists(Arq) then
      Exit;
    Png := TPngImage.Create;
    try
      Png.LoadFromFile(Arq);
      AImagem.Transparent := True;
      AImagem.Stretch := False;
      AImagem.Center := True;
      AImagem.Picture.Assign(Png);
      Result := True;
    finally
      Png.Free;
    end;
  except
    Result := False;
  end;
end;

procedure LiberarCache;
var
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    FreeAndNil(GListas[I]);
    FreeAndNil(GNomes[I]);
  end;
end;

initialization

finalization
  LiberarCache;

end.
