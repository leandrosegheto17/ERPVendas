unit ERPV.Temp.TesteT18;

{
  TEMPORARIO - exercita T16 (validadores), T17 (repositorio) e T18 (servico) em
  execucao real. Remover esta unit e a chamada no .dpr depois do teste.
  Grava e apaga um cliente 'Teste T18' no banco configurado.
}

interface

uses
  ERPV.App.Root;

procedure RodarTesteT18(ARoot: TRootAplicacao);

implementation

uses
  System.SysUtils, Vcl.Dialogs,
  ERPV.Dominio.Cliente, ERPV.Dominio.Enums, ERPV.Core.Erros, ERPV.Core.Validadores;

procedure RodarTesteT18(ARoot: TRootAplicacao);
var
  C, D: TCliente;
  Log: string;
  IdOk: Integer;

  procedure Tenta(const ARotulo: string);
  begin
    try
      C.Id := 0;
      IdOk := ARoot.ClienteService.Salvar(C);
      Log := Log + ARotulo + ': OK id=' + IntToStr(IdOk) + sLineBreak;
    except
      on E: EValidacao do
        Log := Log + ARotulo + ': [' + E.Campo + '] ' + E.Message + sLineBreak;
      on E: Exception do
        Log := Log + ARotulo + ': EXCECAO ' + E.ClassName + ' - ' + E.Message + sLineBreak;
    end;
  end;

begin
  IdOk := 0;
  C := TCliente.Create;
  try
    Log := 'T16: CPF 529.982.247-25=' + BoolToStr(CpfValido('529.982.247-25'), True) +
      ' | CPF 111.111.111-11=' + BoolToStr(CpfValido('111.111.111-11'), True) +
      ' | CNPJ 11.222.333/0001-81=' + BoolToStr(CnpjValido('11.222.333/0001-81'), True) +
      ' | a@b.com=' + BoolToStr(EmailValido('a@b.com'), True) +
      ' | a@b=' + BoolToStr(EmailValido('a@b'), True) + sLineBreak +
      '(esperado: True | False | True | True | False)' + sLineBreak + sLineBreak;
    C.TipoPessoa := tpFisica;
    C.Ativo := True;
    Tenta('1 tudo vazio (esp: [Nome])');
    C.Nome := 'Teste T18';
    Tenta('2 sem CPF (esp: [CpfCnpj] Informe o CPF/CNPJ)');
    C.CpfCnpj := '111.111.111-11';
    Tenta('3 CPF invalido (esp: [CpfCnpj] CPF invalido)');
    C.CpfCnpj := '111.444.777-35'; // CPF valido que NAO esta no seed
    Tenta('4 sem e-mail (esp: [Email] Informe o e-mail)');
    C.Email := 'malformado@';
    Tenta('5 e-mail malformado (esp: [Email] E-mail invalido)');
    C.Email := 'teste@exemplo.com';
    Tenta('6 valido (esp: OK id=N)');
    Tenta('7 CPF duplicado (esp: [CpfCnpj] Documento ja cadastrado)');
    C.TipoPessoa := tpJuridica;
    C.CpfCnpj := '12.345.678/0001-00';
    Tenta('8 CNPJ invalido (esp: [CpfCnpj] CNPJ invalido)');

    // edicao do proprio registro nao pode dar "Documento ja cadastrado";
    // Ativo False/True exercita AsBoolean do BOOLEAN do FB3
    if IdOk > 0 then
    begin
      C.Id := 0;
      D := ARoot.ClienteService.Obter(IdOk);
      try
        if D = nil then
          Log := Log + '9 Obter: NIL (inesperado)' + sLineBreak
        else
        begin
          Log := Log + '9 Obter: doc=' + D.CpfCnpj + ' ativo=' + BoolToStr(D.Ativo, True) +
            ' (esp: 11144477735, True)' + sLineBreak;
          D.Nome := 'Teste T18 editado';
          D.Ativo := False;
          try
            ARoot.ClienteService.Salvar(D);
            Log := Log + '10 Editar mesmo Id + Ativo=False: OK' + sLineBreak;
          except
            on E: Exception do
              Log := Log + '10 Editar: FALHOU ' + E.Message + sLineBreak;
          end;
        end;
      finally
        D.Free;
      end;
      D := ARoot.ClienteService.Obter(IdOk);
      try
        if D <> nil then
          Log := Log + '11 Reler: nome=' + D.Nome + ' ativo=' + BoolToStr(D.Ativo, True) +
            ' (esp: editado, False)' + sLineBreak;
      finally
        D.Free;
      end;
      try
        ARoot.ClienteService.Excluir(IdOk);
        Log := Log + '12 Excluir: OK (cliente de teste removido)' + sLineBreak;
      except
        on E: Exception do
          Log := Log + '12 Excluir: FALHOU ' + E.Message + sLineBreak;
      end;
    end;
    ShowMessage(Log);
  finally
    C.Free;
  end;
end;

end.
