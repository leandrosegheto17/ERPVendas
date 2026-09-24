unit ERPV.Core.Validadores;

{
  T16 (Lote 4) - Validadores puros: CPF, CNPJ (digitos verificadores) e
  e-mail (RF-02). Sem Vcl/FireDAC; so System.SysUtils.

  Regras:
  - CPF/CNPJ aceitam entrada com ou sem mascara; qualquer caractere que nao
    seja digito e descartado. NormalizarDocumento devolve so digitos (e o
    formato gravado no banco, Diretrizes Secao 1).
  - Sequencias de digitos repetidos (000...0 a 999...9) sao rejeitadas.
  - E-mail: formato simples algo@dominio.tld (sem espacos, um unico '@',
    parte local nao vazia, dominio com ao menos um ponto, rotulos nao
    vazios, TLD com 2+ letras). Nao e validacao RFC completa (proposital).

  ==========================================================================
  TABELA DE CASOS (verificada por calculo independente em Node)
  ==========================================================================
  CPF
    529.982.247-25   -> valido
    52998224725      -> valido (sem mascara)
    111.111.111-11   -> invalido (sequencia repetida)
    529.982.247-24   -> invalido (digito verificador errado)
    1234567890       -> invalido (10 digitos)
    ''               -> invalido
  CNPJ
    11.222.333/0001-81 -> valido
    11222333000181     -> valido (sem mascara)
    11.222.333/0001-80 -> invalido (digito verificador errado)
    00.000.000/0000-00 -> invalido (sequencia repetida)
    1122233300018      -> invalido (13 digitos)
  E-mail
    a@b.com            -> valido
    fulano.x@ex.com.br -> valido
    a@b                -> invalido (sem TLD)
    a@.com             -> invalido (rotulo vazio)
    @b.com             -> invalido (parte local vazia)
    a b@c.com          -> invalido (espaco)
    a@@b.com           -> invalido (dois '@')
    ''                 -> invalido
}

interface

// Remove tudo que nao for digito ('0'..'9').
function NormalizarDocumento(const AValor: string): string;

function CpfValido(const AValor: string): Boolean;
function CnpjValido(const AValor: string): Boolean;
function EmailValido(const AValor: string): Boolean;

implementation

uses
  System.SysUtils;

function NormalizarDocumento(const AValor: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValor) do
    if (AValor[I] >= '0') and (AValor[I] <= '9') then
      Result := Result + AValor[I];
end;

function TodosIguais(const ADigitos: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 2 to Length(ADigitos) do
    if ADigitos[I] <> ADigitos[1] then
    begin
      Result := False;
      Exit;
    end;
end;

// Pesos decrescentes a partir de ACount+1 ate 2 sobre os ACount primeiros
// digitos; devolve o digito verificador (0..9).
function DigitoCpf(const ADigitos: string; ACount: Integer): Integer;
var
  I, Soma: Integer;
begin
  Soma := 0;
  for I := 1 to ACount do
    Soma := Soma + (Ord(ADigitos[I]) - Ord('0')) * (ACount + 2 - I);
  Result := (Soma * 10) mod 11;
  if Result = 10 then
    Result := 0;
end;

function DigitoCnpj(const ADigitos: string; ACount: Integer): Integer;
var
  I, Peso, Soma: Integer;
begin
  // Pesos ciclam de 2 a 9 da direita para a esquerda.
  Soma := 0;
  Peso := 2;
  for I := ACount downto 1 do
  begin
    Soma := Soma + (Ord(ADigitos[I]) - Ord('0')) * Peso;
    Inc(Peso);
    if Peso > 9 then
      Peso := 2;
  end;
  Result := Soma mod 11;
  if Result < 2 then
    Result := 0
  else
    Result := 11 - Result;
end;

function CpfValido(const AValor: string): Boolean;
var
  D: string;
begin
  D := NormalizarDocumento(AValor);
  Result := (Length(D) = 11) and not TodosIguais(D)
    and (DigitoCpf(D, 9) = Ord(D[10]) - Ord('0'))
    and (DigitoCpf(D, 10) = Ord(D[11]) - Ord('0'));
end;

function CnpjValido(const AValor: string): Boolean;
var
  D: string;
begin
  D := NormalizarDocumento(AValor);
  Result := (Length(D) = 14) and not TodosIguais(D)
    and (DigitoCnpj(D, 12) = Ord(D[13]) - Ord('0'))
    and (DigitoCnpj(D, 13) = Ord(D[14]) - Ord('0'));
end;

function EmailValido(const AValor: string): Boolean;
var
  E, Local, Dominio, Rotulo, Tld: string;
  P, I, Ponto: Integer;
begin
  Result := False;
  E := Trim(AValor);
  if E = '' then
    Exit;
  for I := 1 to Length(E) do
    if (E[I] <= ' ') or (E[I] = ',') or (E[I] = ';') then
      Exit;
  P := Pos('@', E);
  if (P <= 1) or (Pos('@', Copy(E, P + 1, MaxInt)) > 0) then
    Exit;
  Local := Copy(E, 1, P - 1);
  Dominio := Copy(E, P + 1, MaxInt);
  if Pos('.', Dominio) = 0 then
    Exit;
  // Cada rotulo do dominio precisa ser nao vazio; o ultimo (TLD) tem 2+ letras.
  Tld := '';
  while Dominio <> '' do
  begin
    Ponto := Pos('.', Dominio);
    if Ponto = 0 then
    begin
      Rotulo := Dominio;
      Dominio := '';
    end
    else
    begin
      Rotulo := Copy(Dominio, 1, Ponto - 1);
      Dominio := Copy(Dominio, Ponto + 1, MaxInt);
      if Dominio = '' then
        Exit; // termina em '.'
    end;
    if Rotulo = '' then
      Exit;
    Tld := Rotulo;
  end;
  if Length(Tld) < 2 then
    Exit;
  for I := 1 to Length(Tld) do
    if not (((Tld[I] >= 'a') and (Tld[I] <= 'z')) or ((Tld[I] >= 'A') and (Tld[I] <= 'Z'))) then
      Exit;
  Result := Local <> '';
end;

end.
